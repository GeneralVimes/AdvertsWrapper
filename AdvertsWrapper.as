package 
{
	import com.distriqt.extension.adverts.AdapterStatus;
	import com.distriqt.extension.adverts.InterstitialAd;
	import com.distriqt.extension.adverts.builders.AdRequestBuilder;
	import com.distriqt.extension.adverts.rewarded.RewardedVideoAd;
	import com.distriqt.extension.adverts.events.AdvertsEvent;
	import com.distriqt.extension.adverts.events.InterstitialAdEvent;
	import com.distriqt.extension.adverts.events.RewardedVideoAdEvent;
	import com.distriqt.extension.adverts.events.FullScreenContentEvent;
	import com.distriqt.extension.adverts.Adverts;
	import com.distriqt.extension.adverts.AdvertPlatform;
	import com.distriqt.extension.adverts.ump.ConsentInformation;
	import com.distriqt.extension.adverts.ump.ConsentStatus;
	import com.distriqt.extension.adverts.ump.ConsentRequestParameters;
	import com.distriqt.extension.adverts.ump.events.ConsentInformationEvent;
	import com.distriqt.extension.adverts.ump.events.UserMessagingPlatformEvent;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	//import com.junkbyte.console.Cc;// we recommend to use add junkbyte console for logging	
	
	/**
	 * This is a wrapper for the basic functions of distiqt's Adverts
	 * So that you can just add AdvertsWrapper.as into your project 
	 * 
	 * You can initialize in 2 ways: after your own "GDPR gate" or with Google's UMP form
	 * Show Interstitial ads or Rewarded Videos
	 * Automatically preload them
	 * Define if the ads are not available due to the network connection or because of the player's selection in the Google's UMP form
	 * 
	 * @author Olexiy Izvalov
	 */
	public class AdvertsWrapper 
	{
		static public var self:AdvertsWrapper;
		
		//These are the codes of Admob test ads. Don't forget to change the ones you're using to the real ad codes from your account when you finish testing
		private var adIdBanner:String =					"ca-app-pub-3940256099942544/2934735716";
		private var adIdInterstitial:String =			"ca-app-pub-3940256099942544/4411468910";//Interstitial
		private var adIdInterstitialVideo:String =		"ca-app-pub-3940256099942544/5135589807";
		private var adIdRewardedVideo:String =			"ca-app-pub-3940256099942544/1712485313";//Rewarded video
		private var adIdNativeAdvanced:String =			"ca-app-pub-3940256099942544/3986624511";
		private var adIdNativeAdvancedVideo:String =	"ca-app-pub-3940256099942544/2521693316";
		private var adIdAppOpenAd:String =				"ca-app-pub-3940256099942544/5662855259";		
		
		//ad units for interstitial and rewarded video ads. It was enough for me :)
		private var interstitialAdUnit:InterstitialAd;
		private var rewardedVideoAdUnit:RewardedVideoAd;
		
		//callback function which grants rewards for the player
		private var onRewardGrantedFunction:Function;//function (rewardType:String, rewardValue:int)
		
		//this timer tries to load ads again after a previous load error
		private var timer2LoadAdsAfterError:Timer;
		//flags which define which ads should be loaded from the timer
		private var mustLoadInterstitialFromTimer:Boolean = false;
		private var mustLoadRewardedVideoFromTimer:Boolean = false;		
		
		private var arePersonalizedAdsAllowed:Boolean = true;
		
		private var wasUMPCalled:Boolean = false;//did you call Google's UMP consent form
		private var hasNotAvailableAdsError:Boolean = false;//did you receive "no ads to show" error. 
		//According to developers, Google's UMP solution might prevent serving ads to players at all
		//so in combination with wasUMPCalled the wrapper might give you information if UMP could be a reason
		private var hasNetworkAdsError:Boolean = false;//did you receive ads load error due to network not available

		//Creation of a wrapper
		public function AdvertsWrapper() 
		{
			self = this;
			if (Adverts.isSupported){
				log("\nCALLING Adverts.service.setup")
				Adverts.service.setup( AdvertPlatform.PLATFORM_ADMOB );	
				
				timer2LoadAdsAfterError = new Timer(10000, 0)
				timer2LoadAdsAfterError.addEventListener(TimerEvent.TIMER, onUpdateAdsTimer);
				timer2LoadAdsAfterError.start();	
				
				Adverts.service.addEventListener( AdvertsEvent.INITIALISED, initialisedHandler );
			}else{
				log("Adverts NOT supported")
			}
		}
		
		//There are 2 ways to initialie the ads wrapper to fulfil GDPR
		//1. You may integrate a custom "GDPR" gate, gather player's consent to show personalized or 
		//nonpersonalized ads, and initialize Adverts after that
		//More on that: https://github.com/distriqt/ANE-Adverts/discussions/397
		//In this case you should use this function
		public function initializeAfterOwnPrivacyGate(mayShowPersonalizedAds:Boolean=true):void{
			wasUMPCalled = false;
			mustLoadInterstitialFromTimer = false;
			mustLoadRewardedVideoFromTimer = false;			
			arePersonalizedAdsAllowed = mayShowPersonalizedAds;
			initializeAdverts();
		}

		//2. Or you might want to use Google's UMP platform
		//In this case you should use this function
		//WARNING: the current Google's UMP provides a player to switch the ads off at all
		//More on that: https://github.com/distriqt/ANE-Adverts/discussions/401
		public function initializeAfterGooglesUMPForm():void{
			log("\nCALLING initializeAfterGooglesUMPForm")
			wasUMPCalled = false;
			mustLoadInterstitialFromTimer = false;
			mustLoadRewardedVideoFromTimer = false;
			if (Adverts.service.ump.isSupported){
				log("\nCALLING UMP getConsentInformation")
				var consentInformation:ConsentInformation = Adverts.service.ump.getConsentInformation();
				log(consentInformation);
				log("getConsentStatus=",consentInformation.getConsentStatus());
				log("getConsentType=",consentInformation.getConsentType());
				
				consentInformation.addEventListener( ConsentInformationEvent.CONSENT_INFO_UPDATE_SUCCESS, updateConsentSuccessHandler );
				consentInformation.addEventListener( ConsentInformationEvent.CONSENT_INFO_UPDATE_FAILURE, updateConsentFailureHandler );
				
				Adverts.service.ump.addEventListener( UserMessagingPlatformEvent.CONSENT_FORM_LOAD_FAILURE, formLoadFailure );
				Adverts.service.ump.addEventListener( UserMessagingPlatformEvent.CONSENT_FORM_LOAD_SUCCESS, formLoadSuccess );
				Adverts.service.ump.addEventListener( UserMessagingPlatformEvent.CONSENT_FORM_DISMISSED, formDismissedHandler );
				
				var params:ConsentRequestParameters = new ConsentRequestParameters()
				//params.setConsentDebugSettings(new ConsentDebugSettings().setDebugGeography(DebugGeography.DEBUG_GEOGRAPHY_EEA).addTestDeviceHashedId())
				log("\nCALLING requestConsentInfoUpdate")
				consentInformation.requestConsentInfoUpdate( params );					
			}else{
				log("Adverts ump NOT Supported")
				log("\nCALLING initializeAdverts (ump NOT Supported)")
				initializeAdverts();
			}			
		}
		
		//If you have initialized Adverts from Google UMP Form and the ads are not shown because of the player's selection
		//Then you can ask the player to reinitialize and select different option in the form
		public function reInitGoogleUMPForm():void{
			log("\nCALLING reInitGoogleUMPForm")
			if (Adverts.service.ump.isSupported){
				var consentInformation:ConsentInformation = Adverts.service.ump.getConsentInformation();
				consentInformation.reset();
				initializeAfterGooglesUMPForm();
			}else{
				log("Adverts ump NOT Supported")
			}
		}
		//============================CONSENT CALLBACKS===================================================
		private function updateConsentSuccessHandler(e:ConsentInformationEvent):void 
		{
			log("- updateConsentSuccessHandler")
			var consentInformation:ConsentInformation = Adverts.service.ump.getConsentInformation();
			var sts:int = consentInformation.getConsentStatus();
			log("ConsentStatus:", sts);
			log("ConsentStatus.REQUIRED=", ConsentStatus.REQUIRED,"ConsentStatus.NOT_REQUIRED=", ConsentStatus.NOT_REQUIRED,"ConsentStatus.OBTAINED=", ConsentStatus.OBTAINED,"ConsentStatus.UNKNOWN=", ConsentStatus.UNKNOWN);
			if (sts == ConsentStatus.REQUIRED)
			{
				if (consentInformation.isConsentFormAvailable())
				{
					log("\nCALLING loadConsentForm")
					Adverts.service.ump.loadConsentForm();
				}else{
					log("\nCALLING Adverts.service.initialise (form not available)")
					Adverts.service.initialise();					
				}			
			}else{
				if (sts == ConsentStatus.OBTAINED){
					wasUMPCalled = true;
				}
				log("\nCALLING initializeAdverts (consent not required or obtained)")
				initializeAdverts();
			}			
		}
		
		private function updateConsentFailureHandler(e:ConsentInformationEvent):void 
		{
			log("- updateConsentFailureHandler")
			log( "ERROR: [" + e.error.errorID + "] " + e.error.message );
			log("\nCALLING initializeAdverts (updateConsentFailure)")
			initializeAdverts();
		}
		
		private function formLoadFailure(e:UserMessagingPlatformEvent):void 
		{
			log("- formLoadFailure", e.error.errorID, e.error.name)
			log("\nCALLING initializeAdverts (formLoadFailure)")		
			initializeAdverts();
		}
		
		private function formLoadSuccess(e:UserMessagingPlatformEvent):void 
		{
			log("- formLoadSuccess")
			log("\nCALLING showConsentForm")
			wasUMPCalled = true;
			Adverts.service.ump.showConsentForm();			
		}
		
		private function formDismissedHandler(e:UserMessagingPlatformEvent):void 
		{
			log("- formDismissedHandler")
			log("\nCALLING initializeAdverts (form dismissed)")
			initializeAdverts();			
		}
		
		//============================INITZILIZATION===================================================
		//The reason why it is private is because you should call either 1) initializeAfterOwnPrivacyGate or 2) initializeAfterGooglesUMPForm functions
		private function initializeAdverts():void{
			if (Adverts.isSupported){
				Adverts.service.initialise();
			}			
		}
		
		private function initialisedHandler(e:AdvertsEvent):void 
		{
			log("- initialisedHandler Platform is now initialised and ready to load ad")
			log(e)
			for each (var adapterStatus:AdapterStatus in e.adapterStatus)
			{
				log( "adapter: " + adapterStatus.name + " : " + adapterStatus.state + " [" + adapterStatus.latency + "] - " + adapterStatus.description );
			}
			
			if (Adverts.service.interstitials.isSupported)
			{
				if (!interstitialAdUnit){
					log("creating interstitial")
					interstitialAdUnit = Adverts.service.interstitials.createInterstitialAd();
					log("setAdUnitId interstitial")
					interstitialAdUnit.setAdUnitId(adIdInterstitial);
					interstitialAdUnit.addEventListener( InterstitialAdEvent.LOADED, loadedInterstitialHandler );
					interstitialAdUnit.addEventListener( InterstitialAdEvent.ERROR, errorInterstitialHandler );				
					//interstitial.addEventListener( InterstitialAdEventCLOSED, closedHandler );	
					
					interstitialAdUnit.addEventListener( FullScreenContentEvent.SHOW, showInterstitialHandler );
					interstitialAdUnit.addEventListener( FullScreenContentEvent.FAILED_TO_SHOW, failedToShowInterstitialHandler );
					interstitialAdUnit.addEventListener( FullScreenContentEvent.DISMISSED, dismissedInterstitialHandler );						
				}
				preloadInterstitialAd();
			}else{
				log("interstitial NOT supported")
			}
			if (Adverts.service.rewardedVideoAds.isSupported){
				if (!rewardedVideoAdUnit){
					log("creating rewardedVideo")
					rewardedVideoAdUnit = Adverts.service.rewardedVideoAds.createRewardedVideoAd();
					rewardedVideoAdUnit.setAdUnitId(adIdRewardedVideo);
					
					rewardedVideoAdUnit.addEventListener( RewardedVideoAdEvent.LOADED, loadedRVHandler );
					rewardedVideoAdUnit.addEventListener( RewardedVideoAdEvent.ERROR, errorLoadRVHandler );
					
					rewardedVideoAdUnit.addEventListener( FullScreenContentEvent.SHOW, showRVHandler );
					rewardedVideoAdUnit.addEventListener( FullScreenContentEvent.DISMISSED, dismissedRVHandler );				
					rewardedVideoAdUnit.addEventListener( FullScreenContentEvent.FAILED_TO_SHOW, failed2ShowRVHandler );	
					rewardedVideoAdUnit.addEventListener( RewardedVideoAdEvent.REWARD, rewardRVHandler );					
				}

				
				preloadRewardedVideoAd();
			}else{
				log("rewardedVideoAds NOT supported")
			}			
		}		
		
		//============================AD UNITS LOADING===================================================
		//preloading ad units takes place either after this ads unit had been shown or on a timer (in case if error took place at the previous ad unit loading)
		private function onUpdateAdsTimer(e:TimerEvent):void 
		{
			log("\nCALLING onUpdateAdsTimer");
			if (interstitialAdUnit){
				if (mustLoadInterstitialFromTimer){
					preloadInterstitialAd();					
				}
			}
			if (rewardedVideoAdUnit){
				if (mustLoadRewardedVideoFromTimer){
					preloadRewardedVideoAd();					
				}
			}			
		}
		
		private function preloadInterstitialAd():void{
			log("\nCALLING preloadInterstitialAd")
			if (interstitialAdUnit){
				interstitialAdUnit.load( new AdRequestBuilder().nonPersonalisedAds(!arePersonalizedAdsAllowed).build() );
				mustLoadInterstitialFromTimer = false;
			}
		}		
		
		private function preloadRewardedVideoAd():void{
			log("\nCALLING preloadRewardedVideoAd")
			if (rewardedVideoAdUnit){
				rewardedVideoAdUnit.load( new AdRequestBuilder().nonPersonalisedAds(!arePersonalizedAdsAllowed).build() );
				mustLoadRewardedVideoFromTimer = false;				
			}
		}		
				
		private function loadedInterstitialHandler(e:InterstitialAdEvent):void 
		{
			log("- loadedHandler interstitial loaded and ready to be displayed")
		}
		
		private function errorInterstitialHandler(e:InterstitialAdEvent):void 
		{
			log("- errorHandler Load error occurred. The errorCode will contain more information", "Error", e.errorCode);
			mustLoadInterstitialFromTimer = true;
		}
		
		private function showInterstitialHandler(e:FullScreenContentEvent):void 
		{
			log("- showInterstitialHandler The interstitial has been opened and is now visible to the user ")
		}
		
		private function failedToShowInterstitialHandler(e:FullScreenContentEvent):void 
		{
			log("- failedToShowInterstitialHandler The ad failed to be shown", e.errorCode, e.errorMessage)
			mustLoadInterstitialFromTimer = true;
		}
		
		private function dismissedInterstitialHandler(e:FullScreenContentEvent):void 
		{
			log("- dismissedInterstitialHandler Control has returned to your application")
			// you should reactivate any paused / stopped parts of your application.
			preloadInterstitialAd();
		}
		
		private function loadedRVHandler(e:RewardedVideoAdEvent):void 
		{
			log("- loadedRVHandler rewarded video ad loaded and ready to be displayed")
				
			hasNotAvailableAdsError = false;
			hasNetworkAdsError = false;			
		}
		
		private function errorLoadRVHandler(e:RewardedVideoAdEvent):void 
		{
			log("- errorLoadRVHandler Load error occurred. The errorCode will contain more information", "Error", e.errorCode, e.errorMessage )
			if (e.errorCode==1){
				hasNotAvailableAdsError = true;
			}
			if (e.errorCode==2){
				hasNetworkAdsError = true;
			}
			mustLoadRewardedVideoFromTimer = true;
		}
		
		private function showRVHandler(e:FullScreenContentEvent):void 
		{
			log("- showRVHandler The rewarded video ad has been shown and is now visible to the user")
		}
		
		private function dismissedRVHandler(e:FullScreenContentEvent):void 
		{
			log("- dismissedRVHandler")
			// Control has returned to your application
			// you should reactivate any paused / stopped parts of your application.
			preloadRewardedVideoAd();
		}
		
		private function failed2ShowRVHandler(e:FullScreenContentEvent):void 
		{
			log("- failed2ShowRVHandler", e.errorCode, e.errorMessage)
			// failed2ShowRVHandler
			mustLoadRewardedVideoFromTimer = true;
		}
		
		private function rewardRVHandler(e:RewardedVideoAdEvent):void 
		{
			log("- rewardRVHandler")
			// Here you should reward your user
			if (onRewardGrantedFunction){
				onRewardGrantedFunction(e.rewardType, e.rewardAmount)
				onRewardGrantedFunction = null;
			}
		}
		
		//============================FINDING OUT THE STATES OF AD UNITS===================================================
		//and the reasons which might prevent thm from showing
		public function isRewardedVideoReady():Boolean{
			if (!Adverts.isSupported){
				return false
			}
			
			if (rewardedVideoAdUnit){
				var res:Boolean = rewardedVideoAdUnit.isLoaded();
				return res;
			}else{
				return false
			}			
		}
		
		
		public function isInterstitialReady():Boolean{
			if (!Adverts.isSupported){
				return false
			}
			if (interstitialAdUnit){
				var res:Boolean = interstitialAdUnit.isLoaded();
				return res;
			}else{
				return false
			}			
		}
		
		public function isRewardedAdsUnavailableBecauseOfNetwork():Boolean{
			return hasNetworkAdsError
		}
		
		public function isRewardedAdsUnavailableBecauseOfGoogleUMP():Boolean{
			return hasNotAvailableAdsError && wasUMPCalled;
		}
		
		//============================SHOWING AD UNITS===================================================
		public function showInterstitialAd():void{
			log("\nCALLING showInterstitialAd");
			if (isInterstitialReady()){
				interstitialAdUnit.show();
			}			
		}
		//onGranted: function (String, int)
		public function showRewardedAd(onGranted:Function):void{
			log("\nCALLING showRewardedAd");
			if (isRewardedVideoReady()){
				onRewardGrantedFunction = onGranted;
				rewardedVideoAdUnit.show();
			}			
		}
		
		//============================LOGGING===================================================
		//This is a logging function
		//I recommend using Junkbyte console to log on device 
		//https://www.reddit.com/r/as3/comments/lyg16d/junkbyte_console_very_useful_tool_for_tracking/
		private function log(...strings):void 
		{
			//Cc.log(strings);
			//trace(strings)
		}		
	}

}