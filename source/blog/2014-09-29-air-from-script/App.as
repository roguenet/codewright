package {

import flash.desktop.NativeApplication;
import flash.display.Sprite;
import flash.events.InvokeEvent;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.utils.setTimeout;

public class App extends Sprite {
    public function App () {
        NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE, invoked);
    }

    protected function invoked (event :InvokeEvent) :void {
        NativeApplication.nativeApplication.removeEventListener(InvokeEvent.INVOKE, invoked);

        var outFile :File = new File(File.applicationDirectory.nativePath + "/out.log");
        if (outFile.exists) outFile.deleteFile();
        OUT = new FileStream();
        OUT.open(outFile, FileMode.WRITE);

        // delay for testing, and to show that this can run over multiple frames if necessary
        setTimeout(function () :void {
            // simply dump each of our arguments, one per line
            for each (var arg :String in event.arguments) {
                OUT.writeUTFBytes("arg [" + arg + "]\n");
            }

            exit();
        }, 3000);
    }

    protected function exit () :void {
        OUT.close();
        NativeApplication.nativeApplication.exit();
    }

    protected var OUT :FileStream;
}
}
