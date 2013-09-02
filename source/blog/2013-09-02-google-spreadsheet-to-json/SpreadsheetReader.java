package org.roguenet.util;

import com.google.api.client.googleapis.auth.oauth2.GoogleCredential;
import com.google.common.collect.Iterators;
import com.google.common.collect.Lists;
import com.google.gdata.client.spreadsheet.SpreadsheetService;
import com.google.gdata.data.spreadsheet.Cell;
import com.google.gdata.data.spreadsheet.CellEntry;
import com.google.gdata.data.spreadsheet.CellFeed;
import com.google.gdata.util.ServiceException;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonPrimitive;
import com.samskivert.util.StringUtil;
import java.io.IOException;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;
import java.util.ListIterator;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.roguenet.util.Log.log;

public class SpreadsheetReader {
    /**
     * Finds and reads the spreadsheet for the given levelId.
     */
    public JsonObject readJson (String url, GoogleCredential cred) {
        SpreadsheetService service = new SpreadsheetService("PlixlDashboard");
        service.setOAuth2Credentials(cred);
        try {
            CellFeed feed = service.getFeed(new URL(url), CellFeed.class);
            return readJson(feed);

        } catch (ServiceException se) {
            log.warning("ServiceException reading spreadsheet", se);
        } catch (IOException ioe) {
            log.warning("IOException reading spreadsheet", ioe);
        }
        return null;
    }

    protected JsonObject readJson (CellFeed feed) {
        ListIterator<CellEntry> cellIter = feed.getEntries().listIterator();
        // silly to have to spin up a row list, but Google's API doesn't let me iterate over
        // rows without stopping on the first blank row, which we don't want to do.
        List<SpreadsheetRow> rows = Lists.newArrayList(SpreadsheetRow.empty("{"));
        while (cellIter.hasNext()) rows.addAll(SpreadsheetRow.parse(cellIter));
        rows.add(SpreadsheetRow.empty("}"));
        ListIterator<SpreadsheetRow> rowIter = rows.listIterator();
        JsonObject root = createObject(rowIter);
        if (rowIter.hasNext()) {
            log.warning("Leftover rows", "num", Iterators.size(rowIter));
        }
        return root;
    }

    /**
     * Returns a JsonElement built out of the rows at the current position of rowIter. The first
     * element is expected to have "{" as the key, and processing continues until a corresponding
     * "}" key is found.
     */
    protected JsonObject createObject (ListIterator<SpreadsheetRow> rowIter) {
        if (!rowIter.hasNext()) {
            return null;
        }

        SpreadsheetRow row = rowIter.next();
        if (row.key == null || !row.key.equals("{")) {
            log.warning("Object not started with {", "key", row.key);
            return null;
        }

        JsonObject obj = new JsonObject();
        while (rowIter.hasNext()) {
            row = rowIter.next();
            // Objects require that a key be associated with each value found. Null keys and objects
            // starting without a corresponding key are an error.
            if (row.key == null) {
                log.warning("Null key in object");
            } else if (row.key.equals("}")) {
                // we've found our matching close brace, return results
                return obj;
            } else if (row.key.equals("{") || row.key.equals("[") || row.key.equals("]")) {
                log.warning("Non key in object", "key", row.key);
            } else {
                if (!row.value.isEmpty()) {
                    JsonElement value = getValue(row.value);
                    if (value != null) obj.add(cellKey(row.key), value);
                } else if (!rowIter.hasNext()) {
                    // this row had no value, and there is no next row to contain a value either.
                    log.warning("Obj has no value", "key", row.key);
                } else {
                    // peek at the next row to see if it's a start of an object or array for this
                    // row's key.
                    String key = row.key;
                    row = rowIter.next(); rowIter.previous(); // peek
                    if (row.key.equals("{")) {
                        obj.add(cellKey(key), createObject(rowIter));
                    } else if (row.key.equals("[")) {
                        obj.add(cellKey(key), createArray(rowIter));
                    } else {
                        log.warning("Invalid row after empty obj key", "key", key, "next", row.key);
                    }
                }
            }
        }
        return obj;
    }

    /**
     * Returns a JsonArray corresponding to the rows starting at the current position of the
     * iterator. The rows are expected to start with a "[" key, and processing continues until a
     * corresponding "]" key is found.
     */
    protected JsonArray createArray (ListIterator<SpreadsheetRow> rowIter) {
        SpreadsheetRow row = rowIter.next();
        if (row.key == null || !row.key.equals("[")) {
            log.warning("create array not started with [", row.key);
            return null;
        }

        JsonArray arr = new JsonArray();
        if (!row.value.isEmpty()) {
            // the opening array row can have a value.
            arr.add(getValue(row.value));
        }
        while (rowIter.hasNext()) {
            row = rowIter.next();
            if (row.key == null) {
                arr.add(getValue(row.value));
            } else if (row.key.equals("[")) {
                rowIter.previous();
                arr.add(createArray(rowIter));
            } else if (row.key.equals("{")) {
                rowIter.previous();
                arr.add(createObject(rowIter));
            } else if (row.key.equals("]")) {
                // we found our corresponding array closure, bounce back the result.
                return arr;
            } else {
                log.warning("Bad key while in array", "key", row.key);
            }
        }
        return arr;
    }

    /**
     * Returns a JsonElement containing the value of the list of value strings passed in. If more
     * than one value is given, a JsonArray is returned.
     */
    protected JsonElement getValue (List<String> values) {
        if (values.isEmpty()) return null;
        else if (values.size() == 1) {
            return getValue(values.get(0));
        } else {
            JsonArray arr = new JsonArray();
            for (String value : values) arr.add(getValue(value));
            return arr;
        }
    }

    /**
     * Get a JsonPrimitive for the given String value. Integer, Float and boolean primitives are
     * attempted before falling back to String.
     */
    protected JsonPrimitive getValue (String value) {
        try {
            Number num = Integer.parseInt(value);
            if (num != null) return new JsonPrimitive(num);
            else num = Float.parseFloat(value);
            if (num != null) return new JsonPrimitive(num);
        } catch (NumberFormatException nfe) { /* fallthrough */ }

        // Boolean.parseBoolean will return false for any string not equal to "true", but we only
        // want false if it actually was "false"
        if (value.toLowerCase().equals("true")) return new JsonPrimitive(true);
        else if (value.toLowerCase().equals("false")) return new JsonPrimitive(false);
        else return new JsonPrimitive(value);
    }

    /**
     * Return a valid cell key from the given Spreadsheet key column value. The given key is
     * lower cased and has all spaces replaced by underscores.
     */
    protected String cellKey (String key) {
        StringBuilder camelCase = null;
        for (String part : key.toLowerCase().split(" ")) {
            if (camelCase == null) camelCase = new StringBuilder(part);
            else camelCase.append(part.substring(0, 1).toUpperCase()).append(part.substring(1));
        }
        return camelCase == null ? key : camelCase.toString();
    }

    protected static class SpreadsheetRow {
        public String key;
        public List<String> value;

        /**
         * Returns 0 or more SpreadsheetRows, depending on the content of the row in the spreadsheet
         * that the iterator is expected to be positioned at the start of.
         */
        public static List<SpreadsheetRow> parse (ListIterator<CellEntry> iter) {
            List<SpreadsheetRow> rows = new ArrayList<SpreadsheetRow>();

            List<String> values = new ArrayList<String>();
            Cell keyCell = iter.next().getCell();
            int row = keyCell.getRow();
            String key = keyCell.getValue().trim();
            // comment cells start with "*"
            if (key.startsWith("*")) {
                Cell cell;
                // consume any more cells on this row
                while ((cell = iter.hasNext() ? iter.next().getCell() : null) != null &&
                    cell.getRow() == row);
                if (cell != null && cell.getRow() != row) iter.previous();
                return rows;
            }

            // if our first cell is not in the key column, roll back the iterator so it gets
            // consumed as a value instead
            boolean emptyKey = false;
            if (keyCell.getCol() != 1) {
                iter.previous();
                emptyKey = true;
            }

            // get any valid value cells into the values list.
            Cell valueCell;
            while ((valueCell = iter.hasNext() ? iter.next().getCell() : null) != null &&
                valueCell.getRow() == row) {
                String value = valueCell.getValue().trim();
                if (!value.startsWith("*")) values.add(value);
            }
            // roll back the iterator if we've bumped into the next row.
            if (valueCell != null && valueCell.getRow() != row) iter.previous();

            if (emptyKey) {
                rows.add(new SpreadsheetRow(null, values));
            } else {
                // break up any compound keys into separate key parts. Things like "} Foo Bar {"
                // get broken into "}", "Foo Bar" and "{"
                List<String> keyParts = new ArrayList<String>();
                Matcher m = COMPLEX_CELL.matcher(key);
                boolean found = false;
                int end = 0;
                while (m.find()) {
                    if (found && end != m.start())
                        keyParts.add(key.substring(end, m.start()).trim());
                    end = m.end();
                    if (!found && m.start() > 0) keyParts.add(key.substring(0, m.start()).trim());
                    found = true;
                    keyParts.add(key.substring(m.start(), m.end()).trim());
                }
                if (found) {
                    if (end < key.length() - 1) keyParts.add(key.substring(end).trim());
                } else {
                    keyParts.add(key);
                }

                // Break compound keys into separate rows to make JSON construction much simpler.
                // The values associated with this row in the spreadsheet are attached to the last
                // string key or array opening bracket found in this compound key
                SpreadsheetRow lastRow = null;
                for (String keyPart : keyParts) {
                    if (keyPart.length() == 0) continue;

                    if (keyPart.equals("{")) rows.add(empty(keyPart));
                    else if (keyPart.equals("[")) rows.add(lastRow = empty(keyPart));
                    else if (keyPart.equals("}")) rows.add(empty(keyPart));
                    else if (keyPart.equals("]")) rows.add(empty(keyPart));
                    else rows.add(lastRow = empty(keyPart));
                }
                // if we found a valid key for storing a value, attach this row's value to it
                if (lastRow != null) lastRow.value.addAll(values);
            }
            return rows;
        }

        public static SpreadsheetRow empty (String key) {
            return new SpreadsheetRow(key, Lists.<String>newArrayList());
        }

        public SpreadsheetRow (String key, List<String> value) {
            this.key = key;
            this.value = value;
        }

        @Override public String toString () {
            return "Row [" + key + ", " + StringUtil.toString(value) + "]";
        }
    }

    protected static final Pattern COMPLEX_CELL = Pattern.compile("[\\[\\]\\{\\}]");
}
