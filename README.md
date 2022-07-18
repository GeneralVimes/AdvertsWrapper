# AdvertsWrapper
Wrapper for distriqt / ANE-Adverts which handles service functions and ready to be added to a game as a single AdvertsWrapper.as class. 

This is what it can do:

- 2 ways of initialization: after your own "GDPR gate" or with Google's UMP form
- Show Interstitial ads or Rewarded Videos
- Automatically preload them
- Define if the ads are not available due to the network connection or because of the player's selection in the Google's UMP form

Usage:

0. Add the Distriqt's Adverts extension to your project as it's explained in Get Stated section of https://docs.airnativeextensions.com/docs/adverts/add-the-extension 
1. Add AdvertsWrapper.as into your project
2. Create an instance by calling 
`var adsWrapper:AdvertsWrapper = new AdvertsWrapper()`
You can do this after you init Core and (on iOS) request IDFA authorisation
3. There are 2 ways to intialize:
**3a.** If you have a custom made GDPR gate in your game, call
`AdvertsWrapper.self.initializeAfterOwnPrivacyGate(mayShowPersonalizedAds:Boolean)`
after the player has agreed to your terms of service and selected the type of ads served in the game.
More discussion on the custom GDPR gate creation is here: https://github.com/distriqt/ANE-Adverts/discussions/397
**3b.** You can use Google's UMP solution to gather player's consent by calling 
`AdvertsWrapper.self.initializeAfterGooglesUMPForm()`
Warning: the current version of Google's UMP might prevent ads from loading at all (both personalized and non-personalized) after certain player's selections in the form. This is entirely Google's problem discussed here: https://github.com/distriqt/ANE-Adverts/discussions/401. Further on we explain a workaround how to make the player change a decision like that.
4. AdvertsWrapper tries to preload ads automatically, you don't need to handle this from outside. After an error in the preloading the built-in timer starts the next attempt in 10 seconds. Also it's possible to define the reason of the ads loading error: can it ne a network connection or Google UMP form. You can call the following Boolean functions:
```
AdvertsWrapper.self.isInterstitialReady()
AdvertsWrapper.self.isRewardedVideoReady()
AdvertsWrapper.self.isRewardedAdsUnavailableBecauseOfNetwork()
AdvertsWrapper.self.isRewardedAdsUnavailableBecauseOfGoogleUMP()
```
5. In my games I use only Interstitial ads and Rewarded video ads, so, I added only them into the AdvertsWrapper. To call the ads use the functions:
```
AdvertsWrapper.self.showInterstitialAd()
AdvertsWrapper.self.showRewardedAd(onGranted:Function)
```
`onGranted` is a function `(String, int)` which defines what will happen if the user completes watching a rewarded video ad

6. Modifications inside AdvertsWrapper
Logging. There is a private function log() in AdvertsWrapper.as which you can use to log its behavior. From own experience I recommend to call jukbyte console's Cc.log function from it. More on this useful tool: https://www.reddit.com/r/as3/comments/lyg16d/junkbyte_console_very_useful_tool_for_tracking/
Real ad units. When you finished testing and ready to integrate real ads replace the values of private variables `adIdInterstitial` and `adIdRewardedVideo` with your actual ad units codes.

7. Informing the player about the absence of ads and the actions needed.
As noted above, some of player's selection in Google's UMP form can lead to absolute absence of ads. You can reset the player's selection and ask to complete the form again by calling
`AdvertsWrapper.self.reInitGoogleUMPForm()`
This function can be used in the following context, for example, when a user presses a button "Get reward after watching a video":

```
if (AdvertsWrapper.self.isRewardedVideoReady()){
	AdvertsWrapper.self.showRewardedAd(onGranted);
}else{
	if (AdvertsWrapper.self.isRewardedAdsUnavailableBecauseOfNetwork()){
		//show a message like: "Please check your internet connection"
	}else{
		if (AdvertsWrapper.self.isRewardedAdsUnavailableBecauseOfGoogleUMP()){
			//show a message like: "Please accept ads preferences to view ads and gain reward"
			//and when this message is closed call a function AdvertsWrapper.reInitGoogleUMPForm()
		}
	}
}
```
The button which provides a reward for watching an ad should be visible if the following condition is true:
`AdvertsWrapper.self.isRewardedVideoReady() || AdvertsWrapper.self.isRewardedAdsUnavailableBecauseOfNetwork() || AdvertsWrapper.self.isRewardedAdsUnavailableBecauseOfGoogleUMP();`
More on this in these Youtube videos I made:
https://youtu.be/z70s9Us51H8
https://youtu.be/9EN4S-nyy4s
