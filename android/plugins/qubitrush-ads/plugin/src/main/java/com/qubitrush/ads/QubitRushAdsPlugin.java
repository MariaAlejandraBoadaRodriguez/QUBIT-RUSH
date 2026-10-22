package com.qubitrush.ads;

import android.app.Activity;
import android.util.Log;

import androidx.annotation.NonNull;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.RequestConfiguration;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import com.google.android.ump.ConsentInformation;
import com.google.android.ump.ConsentRequestParameters;
import com.google.android.ump.UserMessagingPlatform;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Thin bridge between GDScript (AdsService / ConsentService) and the official
 * Google Mobile Ads SDK + User Messaging Platform. All policy decisions live in
 * GDScript; this class only reports what the SDK did. Every call is safe at any
 * time: failures are reported as signals and never throw into the game.
 *
 * Written in Java on purpose: the Ads SDK ships newer Kotlin metadata than the
 * Kotlin version used by the Godot 4.7 Gradle template.
 */
public class QubitRushAdsPlugin extends GodotPlugin {
    private static final String TAG = "QubitRushAds";

    private RewardedAd rewarded;
    private InterstitialAd interstitial;
    private final AtomicBoolean initialized = new AtomicBoolean(false);

    public QubitRushAdsPlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "QubitRushAds";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> s = new HashSet<>();
        s.add(new SignalInfo("initialized", Boolean.class));
        s.add(new SignalInfo("consent_status", String.class, Boolean.class));
        s.add(new SignalInfo("rewarded_loaded"));
        s.add(new SignalInfo("rewarded_failed_to_load", String.class));
        s.add(new SignalInfo("rewarded_shown"));
        s.add(new SignalInfo("rewarded_failed_to_show", String.class));
        s.add(new SignalInfo("reward_earned", String.class));
        s.add(new SignalInfo("rewarded_dismissed"));
        s.add(new SignalInfo("interstitial_loaded"));
        s.add(new SignalInfo("interstitial_failed_to_load", String.class));
        s.add(new SignalInfo("interstitial_dismissed"));
        return s;
    }

    private interface UiTask {
        void run(Activity act);
    }

    private void onUi(UiTask task) {
        final Activity act = getActivity();
        if (act == null) {
            return;
        }
        act.runOnUiThread(() -> {
            try {
                task.run(act);
            } catch (Exception e) {
                Log.w(TAG, "Ads call failed", e);
            }
        });
    }

    private static String statusName(ConsentInformation info) {
        switch (info.getConsentStatus()) {
            case ConsentInformation.ConsentStatus.OBTAINED:
                return "obtained";
            case ConsentInformation.ConsentStatus.NOT_REQUIRED:
                return "not_required";
            case ConsentInformation.ConsentStatus.REQUIRED:
                return "required";
            default:
                return "unknown";
        }
    }

    /** Google UMP flow. Shows a form only when the SDK says one is required. */
    @UsedByGodot
    public void requestConsent(boolean underAgeOfConsent) {
        onUi(act -> {
            ConsentRequestParameters params = new ConsentRequestParameters.Builder()
                    .setTagForUnderAgeOfConsent(underAgeOfConsent)
                    .build();
            ConsentInformation info = UserMessagingPlatform.getConsentInformation(act);
            info.requestConsentInfoUpdate(act, params,
                    () -> UserMessagingPlatform.loadAndShowConsentFormIfRequired(act, formError -> {
                        if (formError != null) {
                            Log.w(TAG, "Consent form: " + formError.getMessage());
                        }
                        emitSignal("consent_status", statusName(info), info.canRequestAds());
                    }),
                    error -> {
                        Log.w(TAG, "Consent info update failed: " + error.getMessage());
                        emitSignal("consent_status", "error", info.canRequestAds());
                    });
        });
    }

    @UsedByGodot
    public void showPrivacyOptionsForm() {
        onUi(act -> UserMessagingPlatform.showPrivacyOptionsForm(act, err -> {
            if (err != null) {
                Log.w(TAG, "Privacy options: " + err.getMessage());
            }
            ConsentInformation info = UserMessagingPlatform.getConsentInformation(act);
            emitSignal("consent_status", statusName(info), info.canRequestAds());
        }));
    }

    @UsedByGodot
    public void resetConsent() {
        onUi(act -> UserMessagingPlatform.getConsentInformation(act).reset());
    }

    /** Initialise only after GDScript has confirmed consent allows ad requests. */
    @UsedByGodot
    public void initialize(boolean testMode, boolean childSafe, String maxContentRating) {
        onUi(act -> {
            if (!UserMessagingPlatform.getConsentInformation(act).canRequestAds()) {
                emitSignal("initialized", false);
                return;
            }
            String rating;
            switch (maxContentRating) {
                case "PG":
                    rating = RequestConfiguration.MAX_AD_CONTENT_RATING_PG;
                    break;
                case "T":
                    rating = RequestConfiguration.MAX_AD_CONTENT_RATING_T;
                    break;
                case "MA":
                    rating = RequestConfiguration.MAX_AD_CONTENT_RATING_MA;
                    break;
                default:
                    rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G;
            }
            RequestConfiguration config = new RequestConfiguration.Builder()
                    .setMaxAdContentRating(rating)
                    .setTagForChildDirectedTreatment(childSafe
                            ? RequestConfiguration.TAG_FOR_CHILD_DIRECTED_TREATMENT_TRUE
                            : RequestConfiguration.TAG_FOR_CHILD_DIRECTED_TREATMENT_UNSPECIFIED)
                    .setTagForUnderAgeOfConsent(childSafe
                            ? RequestConfiguration.TAG_FOR_UNDER_AGE_OF_CONSENT_TRUE
                            : RequestConfiguration.TAG_FOR_UNDER_AGE_OF_CONSENT_UNSPECIFIED)
                    .build();
            MobileAds.setRequestConfiguration(config);
            Log.i(TAG, "Initialising Mobile Ads (testMode=" + testMode + ", childSafe=" + childSafe + ")");
            MobileAds.initialize(act, status -> {
                initialized.set(true);
                emitSignal("initialized", true);
            });
        });
    }

    @UsedByGodot
    public void loadRewarded(String unitId) {
        onUi(act -> {
            if (!initialized.get()) {
                emitSignal("rewarded_failed_to_load", "not_initialized");
                return;
            }
            RewardedAd.load(act, unitId, new AdRequest.Builder().build(), new RewardedAdLoadCallback() {
                @Override
                public void onAdLoaded(@NonNull RewardedAd ad) {
                    rewarded = ad;
                    emitSignal("rewarded_loaded");
                }

                @Override
                public void onAdFailedToLoad(@NonNull LoadAdError error) {
                    rewarded = null;
                    emitSignal("rewarded_failed_to_load", error.getCode() + ":" + error.getMessage());
                }
            });
        });
    }

    @UsedByGodot
    public void showRewarded() {
        onUi(act -> {
            RewardedAd ad = rewarded;
            if (ad == null) {
                emitSignal("rewarded_failed_to_show", "not_loaded");
                return;
            }
            rewarded = null;
            // One id per show: duplicate SDK callbacks for the same show share
            // it, which lets GDScript grant the reward exactly once.
            final String showId = UUID.randomUUID().toString();
            ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdShowedFullScreenContent() {
                    emitSignal("rewarded_shown");
                }

                @Override
                public void onAdFailedToShowFullScreenContent(@NonNull AdError error) {
                    emitSignal("rewarded_failed_to_show", error.getCode() + ":" + error.getMessage());
                }

                @Override
                public void onAdDismissedFullScreenContent() {
                    emitSignal("rewarded_dismissed");
                }
            });
            // The reward is reported only from the SDK's earned-reward callback.
            ad.show(act, rewardItem -> emitSignal("reward_earned", showId));
        });
    }

    @UsedByGodot
    public void loadInterstitial(String unitId) {
        onUi(act -> {
            if (!initialized.get()) {
                emitSignal("interstitial_failed_to_load", "not_initialized");
                return;
            }
            InterstitialAd.load(act, unitId, new AdRequest.Builder().build(), new InterstitialAdLoadCallback() {
                @Override
                public void onAdLoaded(@NonNull InterstitialAd ad) {
                    interstitial = ad;
                    emitSignal("interstitial_loaded");
                }

                @Override
                public void onAdFailedToLoad(@NonNull LoadAdError error) {
                    interstitial = null;
                    emitSignal("interstitial_failed_to_load", error.getCode() + ":" + error.getMessage());
                }
            });
        });
    }

    @UsedByGodot
    public void showInterstitial() {
        onUi(act -> {
            InterstitialAd ad = interstitial;
            if (ad == null) {
                emitSignal("interstitial_dismissed");
                return;
            }
            interstitial = null;
            ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdDismissedFullScreenContent() {
                    emitSignal("interstitial_dismissed");
                }

                @Override
                public void onAdFailedToShowFullScreenContent(@NonNull AdError error) {
                    emitSignal("interstitial_dismissed");
                }
            });
            ad.show(act);
        });
    }
}
