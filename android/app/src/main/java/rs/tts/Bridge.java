package rs.tts;

import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.util.Log;
import androidx.annotation.Keep;

@Keep
public class Bridge extends UtteranceProgressListener implements TextToSpeech.OnInitListener {
    private static final String TAG = "rs.tts.Bridge";
    public int backendId;

    public Bridge(int backendId) {
        this.backendId = backendId;
        Log.i(TAG, "Bridge created with backendId=" + backendId);
    }

    @Override
    public native void onInit(int status);

    @Override
    public native void onStart(String utteranceId);

    /**
     * UtteranceProgressListener.onStop(String, boolean) has 2 params,
     * but tts crate's JNI export Java_rs_tts_Bridge_onStop only accepts
     * (JNIEnv, JObject, JString) — 1 param. The JNI mangled name for
     * the 2-param overload would be different, so the crate's function
     * is never found. We bridge this by wrapping in a non-native method.
     */
    @Override
    public void onStop(String utteranceId, boolean interrupted) {
        Log.d(TAG, "onStop: " + utteranceId + ", interrupted=" + interrupted);
        nativeOnStop(utteranceId);
    }

    // This matches tts crate's exported Java_rs_tts_Bridge_nativeOnStop
    private native void nativeOnStop(String utteranceId);

    @Override
    public native void onDone(String utteranceId);

    @Override
    @Deprecated
    public native void onError(String utteranceId);
}
