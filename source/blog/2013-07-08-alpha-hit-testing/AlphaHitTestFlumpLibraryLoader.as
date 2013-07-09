package {

import aspire.util.Log;
import aspire.util.Map;
import aspire.util.Maps;

import flash.geom.Rectangle;
import flash.utils.ByteArray;
import flash.utils.getTimer;

import flashbang.resource.FlumpLibraryLoader;

import flump.display.LibraryLoader;
import flump.executor.load.LoadedImage;
import flump.mold.AtlasMold;

/**
 * A flump library loader that hooks into flump loading to allow the Images loaded from this
 * library to have an improved hitTest method that uses the alpha from the original texture instead
 * of the clip rect of the Image.
 *
 * In order to save space, only a single bit is stored per non-retina atlas pixel: whether that
 * location is fully transparent or not. That is the test used to determine if a given hitTest()
 * will pass or fail.
 */
public class AlphaHitTestFlumpLibraryLoader extends FlumpLibraryLoader {
    public function AlphaHitTestFlumpLibraryLoader (params :Object) {
        super(params);
    }

    override protected function createLibraryLoader () :LibraryLoader {
        var loader :LibraryLoader = super.createLibraryLoader()
            .setCreatorFactory(new AlphaHitTestCreatorFactory(_atlasMap));
        loader.pngAtlasLoaded.add(pngAtlasLoaded);
        return loader;
    }

    protected function pngAtlasLoaded (atlas :AtlasMold, image :LoadedImage) :void {
        var start :int = getTimer();
        var pixels :ByteArray = image.bitmapData.getPixels(new Rectangle(0, 0,
            image.bitmapData.width, image.bitmapData.height));
        var w :int = image.bitmapData.width;
        var h :int = image.bitmapData.height;
        pixels.position = 0;
        var alphaBits :ByteArray = new ByteArray();
        var current :int = 0;
        var idx :int = 7;
        var row :int = 0;
        var rowsSkipped :int = 0;
        var col :int = 0;
        var colsSkipped :int = 0;
        var numColumns :int = 0;
        while (pixels.bytesAvailable > 0) {
            var pixel :uint = pixels.readUnsignedInt();
            if (pixel >> 24 != 0) current = current | (1 << idx);
            if (idx == 0) {
                alphaBits.writeByte(current);
                current = 0;
                idx = 7;
            } else {
                idx--;
            }

            // skip pixels as necessary to maintain our logical scale factor
            // Note: this won't work for scaleFactors < 1, it would need to be smart enough to
            // skip multiple columns/rows at a time.
            col++;
            if (col / (col - colsSkipped) < atlas.scaleFactor) {
                var newCol :int = Math.min(col + 1, w);
                pixels.position += (newCol - col) * 4;
                colsSkipped += newCol - col;
                col = newCol;
            }
            if (col == w) {
                if (numColumns != 0 && numColumns != col - colsSkipped) {
                    log.warning("Column sizes disagree!", "prev", numColumns, "new",
                        col - colsSkipped);
                }
                numColumns = col - colsSkipped;
                row++;
                col = 0;
                colsSkipped = 0;
                if (row / (row - rowsSkipped) < atlas.scaleFactor && row != h) {
                    pixels.position += w * 4;
                    rowsSkipped++;
                    row++;
                }
            }
            if (row == h && pixels.bytesAvailable > 0) {
                log.warning("Covered the full image, but bytes are available",
                    "size", "(" + w + ", " + h + ")", "avail", pixels.bytesAvailable);
                break;
            }
        }
        // make sure we write the last byte
        if (idx != 7) {
            alphaBits.writeByte(current);
        }
        var mask :AlphaMask = new AlphaMask(alphaBits, numColumns, row - rowsSkipped);
        // TODO: potential compile time process to precalculate these if this takes too long.
        // Update: this is wicked slow, not acceptable for release, will need to precalculate
        // for production builds. 5s on desktop, 14s on iPad2
        log.info("finished calculating alpha bits", "name", atlas.file, "bitmapSize", pixels.length,
            "maskSize", alphaBits.length, "time", getTimer() - start);

        _atlasMap.put(atlas.file, mask);
    }

    protected var _atlasMap :Map = Maps.newMapOf(String); // <String, AlphaMask>

    protected static const log :Log = Log.getLog(AlphaHitTestFlumpLibraryLoader);
}
}

import aspire.util.Log;
import aspire.util.Map;

import flash.geom.Point;
import flash.utils.ByteArray;

import flump.display.CreatorFactoryImpl;
import flump.display.ImageCreator;
import flump.display.Library;
import flump.mold.AtlasMold;
import flump.mold.AtlasTextureMold;

import starling.display.DisplayObject;
import starling.display.Image;
import starling.textures.Texture;

class AlphaMask {
    public var bits :ByteArray;
    public var width :int;
    public var height :int;

    public function AlphaMask (bits :ByteArray, width :int, height :int) {
        this.bits = bits;
        this.width = width;
        this.height = height;
    }

    public function isOpaque (pos :Point) :Boolean {
        var bitIdx :int = Math.floor(pos.y) * width + Math.floor(pos.x);
        var byteMask :int = bits[Math.floor(bitIdx / 8)];
        bitIdx = 7 - (bitIdx % 8);
        return (byteMask & (1 << bitIdx)) > 0;
    }
}

class AlphaHitTestCreatorFactory extends CreatorFactoryImpl {
    public function AlphaHitTestCreatorFactory (alphaMasks :Map) {
        _alphaMasks = alphaMasks;
    }

    override public function createImageCreator (mold :AtlasTextureMold, texture :Texture,
        origin :Point, symbol :String) :ImageCreator {
        var offset :Point = new Point();
        offset.x = Math.floor(mold.bounds.x / _scaleFactor);
        offset.y = Math.floor(mold.bounds.y / _scaleFactor);
        return new AlphaHitTestImageCreator(texture, origin, symbol, _currentMask, offset);
    }

    override public function consumingAtlasMold (mold :AtlasMold) :void {
        super.consumingAtlasMold(mold);

        _scaleFactor = mold.scaleFactor;
        _currentMask = _alphaMasks.get(mold.file);
        if (_currentMask == null) {
            log.error("No bits for atlas, Images generated will use default hit testing",
                "atlas", mold.file);
        }
    }

    protected var _scaleFactor :Number;
    protected var _currentMask :AlphaMask;
    protected var _alphaMasks :Map; // <String, AlphaMask>

    protected static const log :Log = Log.getLog(AlphaHitTestCreatorFactory);
}

class AlphaHitTestImageCreator extends ImageCreator {
    function AlphaHitTestImageCreator (texture :Texture, origin :Point, symbol :String,
        alphaMask :AlphaMask, textureOffset :Point) {
        super(texture, origin, symbol);
        _alphaMask = alphaMask;
        _textureOffset = textureOffset;
    }

    override public function create (library :Library) :DisplayObject {
        const image :AlphaHitTestImage = new AlphaHitTestImage(texture, _alphaMask, _textureOffset);
        image.pivotX = origin.x;
        image.pivotY = origin.y;
        image.name = symbol;
        return image;
    }

    protected var _alphaMask :AlphaMask;
    protected var _textureOffset :Point;
}

class AlphaHitTestImage extends Image {
    function AlphaHitTestImage (texture :Texture, alphaMask :AlphaMask, baseOffset :Point) {
        super(texture);
        _alphaMask = alphaMask;
        _baseOffset = baseOffset;
    }

    override public function hitTest (localPoint :Point, forTouch :Boolean = false) :DisplayObject {
        var inBounds :Boolean = super.hitTest(localPoint, forTouch) == this;
        if (!inBounds) return null;

        // super says this is a hit, let's check the alpha map.
        return _alphaMask.isOpaque(_baseOffset.add(localPoint)) ? this : null;
    }

    protected var _alphaMask :AlphaMask;
    protected var _baseOffset :Point;
}
