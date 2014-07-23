package {

import flash.display.Sprite;
import flash.display.Stage3D;
import flash.display3D.Context3DProfile;
import flash.display3D.Context3DRenderMode;
import flash.events.ErrorEvent;
import flash.events.Event;
import flash.utils.setTimeout;

import react.Future;
import react.Promise;

import starling.core.Starling;
import starling.display.Sprite;
import starling.events.Event;

public class App extends flash.display.Sprite {
    public function App () {
        addEventListener(Event.ADDED_TO_STAGE, addedToStage);
    }

    protected function addedToStage (e :flash.events.Event) :void {
        initStage3D()
            .onFailure(function (e :ErrorEvent) :void {
                trace("Stage 3D error [" + e.toString() + "]");
            }).onSuccess(initStarling);
    }

    protected function initStarling (profile :String) :void {
        var stage3D :Stage3D = stage.stage3Ds[0];
        trace("Stage 3D init complete [" + profile + ", " + stage3D.context3D.driverInfo + "]");

        var starlingInst :Starling = new Starling(starling.display.Sprite, stage, null, stage3D,
            Context3DRenderMode.AUTO, profile);
        // we're not actually sharing context, but because we passed Starling a stage3D that is
        // already initialized, it thinks we are.
        starlingInst.shareContext = false;
        starlingInst.addEventListener(starling.events.Event.ROOT_CREATED, run);
        starlingInst.start();
    }

    protected function run (e :starling.events.Event) :void {
        var starlingInst :Starling = Starling(e.target);
        starlingInst.removeEventListener(starling.events.Event.ROOT_CREATED, run);

        // Starling is good to go, let the game building commence!
    }

    /**
     * Initializes the first available Stage3D with the best Context3D it can support. Will fall
     * back to software rendering in Context3DProfile.BASELINE_CONSTRAINED if necessary.
     *
     * @return a Future that may succeed with the profile in use by the newly initialized
     *         Context3D.
     */
    protected function initStage3D () :Future {
        var stage3D :Stage3D = stage.stage3Ds[0];

        // try all three profiles in descending order of complexity
        var profiles :Vector.<String> = new <String>[ Context3DProfile.BASELINE_EXTENDED,
            Context3DProfile.BASELINE, Context3DProfile.BASELINE_CONSTRAINED ];
        var currentProfile :String;
        stage3D.addEventListener(flash.events.Event.CONTEXT3D_CREATE, onCreated);
        stage3D.addEventListener(ErrorEvent.ERROR, onError);
        var promise :Promise = new Promise();

        function requestNextProfile () :void {
            // pull off the next profile and try to init Stage3D with it
            currentProfile = profiles.shift();

            try {
                stage3D.requestContext3D(Context3DRenderMode.AUTO, currentProfile);
            } catch (e :Error) {
                if (profiles.length > 0) {
                    // try again next frame
                    setTimeout(requestNextProfile, 1);
                } else throw e;
            }
        }

        function onCreated (e :flash.events.Event) :void {
            var isSoftwareMode :Boolean =
                stage3D.context3D.driverInfo.toLowerCase().indexOf("software") >= 0;
            if (isSoftwareMode && profiles.length > 0) {
                // don't settle for software mode if there are more hardware profiles to try
                setTimeout(requestNextProfile, 1);
                return;
            }

            // We've found a working profile. Clean up and exit.
            cleanup();
            promise.succeed(currentProfile);
        }

        function onError (e :ErrorEvent) :void {
            // if we have another profile to try, try it; else fail for good
            if (profiles.length > 0) setTimeout(requestNextProfile, 1);
            else {
                cleanup();
                promise.fail(e);
            }
        }

        function cleanup () :void {
            stage3D.removeEventListener(flash.events.Event.CONTEXT3D_CREATE, onCreated);
            stage3D.removeEventListener(ErrorEvent.ERROR, onError);
        }

        // kick off the process by requesting the first profile.
        requestNextProfile();
        return promise;
    }
}
}
