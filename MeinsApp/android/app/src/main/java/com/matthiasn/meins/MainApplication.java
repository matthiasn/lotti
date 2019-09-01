package com.matthiasn.meins;

import android.app.Application;

import com.facebook.react.ReactApplication;
import com.oblador.keychain.KeychainPackage;
import com.bitgo.randombytes.RandomBytesPackage;
import com.horcrux.svg.SvgPackage;
import com.reactnativecommunity.asyncstorage.AsyncStoragePackage;
import com.apsl.versionnumber.RNVersionNumberPackage;
import io.realm.react.RealmReactPackage;
import com.oblador.vectoricons.VectorIconsPackage;
import com.swmansion.gesturehandler.react.RNGestureHandlerPackage;
import com.masteratul.exceptionhandler.ReactNativeExceptionHandlerPackage;
import com.rt2zz.reactnativecontacts.ReactNativeContacts;
import org.reactnative.camera.RNCameraPackage;
import com.reactlibrary.RNMailCorePackage;
import com.dooboolab.RNAudioRecorderPlayerPackage;
import com.mapbox.rctmgl.RCTMGLPackage;
import com.reactnativecommunity.cameraroll.CameraRollPackage;
import com.reactnativecommunity.geolocation.GeolocationPackage;
import com.reactnativecommunity.netinfo.NetInfoPackage;
import com.facebook.react.ReactNativeHost;
import com.facebook.react.ReactPackage;
import com.facebook.react.shell.MainReactPackage;
import com.facebook.soloader.SoLoader;

import java.util.Arrays;
import java.util.List;

public class MainApplication extends Application implements ReactApplication {

    private final ReactNativeHost mReactNativeHost = new ReactNativeHost(this) {
        @Override
        public boolean getUseDeveloperSupport() {
            return BuildConfig.DEBUG;
        }

        @Override
        protected List<ReactPackage> getPackages() {
            return Arrays.<ReactPackage>asList(
                    new MainReactPackage(),
                    new KeychainPackage(),
                    new RandomBytesPackage(),
                    new SvgPackage(),
                    new AsyncStoragePackage(),
                    new RNVersionNumberPackage(),
                    new NetInfoPackage(),
                    new RealmReactPackage(),
                    new VectorIconsPackage(),
                    new RNGestureHandlerPackage(),
                    new ReactNativeExceptionHandlerPackage(),
                    new ReactNativeContacts(),
                    new RCTMGLPackage(),
                    new RNCameraPackage(),
                    new RNMailCorePackage(),
                    new RNAudioRecorderPlayerPackage(),
                    new CameraRollPackage(),
                    new GeolocationPackage()
            );
        }

        @Override
        protected String getJSMainModuleName() {
            return "app/index";
        }
    };

    @Override
    public ReactNativeHost getReactNativeHost() {
        return mReactNativeHost;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        SoLoader.init(this, /* native exopackage */ false);
    }
}
