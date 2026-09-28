import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/constants/app_constants.dart';

class AdsService {
  AdsService({this.enabled = true});

  final bool enabled;
  BannerAd? bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  Future<void> initialize() async {
    if (!enabled) return;
    await MobileAds.instance.initialize();
  }

  Widget banner() {
    if (!enabled) return const SizedBox.shrink();

    final ad = BannerAd(
      adUnitId: kBannerAdUnitIdAndroid,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {},
        onAdFailedToLoad: (_, error) {},
      ),
    );
    bannerAd = ad;
    return SizedBox(
      height: 60,
      child: AdWidget(ad: ad),
    );
  }

  Future<void> showInterstitial() async {
    if (!enabled) return;
    if (_interstitialAd != null) {
      await _interstitialAd!.show();
      _interstitialAd = null;
      return;
    }
    await InterstitialAd.load(
      adUnitId: kInterstitialAdUnitIdAndroid,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
            },
          );
        },
        onAdFailedToLoad: (error) {},
      ),
    );
    if (_interstitialAd != null) {
      await _interstitialAd!.show();
      _interstitialAd = null;
    }
  }

  Future<void> showRewarded() async {
    if (!enabled) return;
    if (_rewardedAd != null) {
      await _rewardedAd!.show(onUserEarnedReward: (_, _) {});
      _rewardedAd = null;
      return;
    }
    await RewardedAd.load(
      adUnitId: kRewardedAdUnitIdAndroid,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
            },
          );
        },
        onAdFailedToLoad: (error) {},
      ),
    );
    if (_rewardedAd != null) {
      await _rewardedAd!.show(onUserEarnedReward: (_, _) {});
      _rewardedAd = null;
    }
  }
}
