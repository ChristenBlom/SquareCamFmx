unit uFMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  Macapi.ObjectiveC, iOSapi.Foundation, Macapi.Dispatch, iOSapi.AVFoundation,
  iOSapi.CoreMedia, iOSapi.CocoaTypes, iOSapi.UIKit, iOSapi.CoreImage,
  SyncObjs, iOSapi.CoreGraphics, Macapi.CoreServices, Posix.SysTypes,
  Macapi.CoreFoundation, iOSapi.QuartzCore, FMX.Layouts;

{$DEFINE CALLBACK_ERRORS} // Because of an error in XD5 update 2 second parameter of
                          // callback method is improperly initialized

type
{$M+}
  TFMain = class;

  VideoCaptureDelegate = interface(IObjectiveC)
    ['{95C26C24-9DB3-441A-A60D-A20E96BEF584}']
    procedure observeValueForKeyPath(keyPath: NSString; ofObject: Pointer; change: NSDictionary; context: Pointer); cdecl;
    procedure flashAnimationDidStop(animationID: NSString; finished: NSNumber; context: Pointer); cdecl;
  end;

  TVideoCaptureDelegate = class(TOCLocal, VideoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate)
  private
    [Weak] FMain: TFMain;
    FFlashView: UIView;
  public
    constructor Create(Main: TFMain);
    procedure observeValueForKeyPath(keyPath: NSString; ofObject: Pointer; change: NSDictionary; context: Pointer); cdecl;
    procedure captureOutput(captureOutput: AVCaptureOutput; didOutputSampleBuffer: CMSampleBufferRef; fromConnection: AVCaptureConnection); cdecl;
    procedure flashAnimationDidStop(animationID: NSString; finished: NSNumber; context: Pointer); cdecl;
    procedure FlashAnimation(Flash: Boolean);
  end;

{ AVCaptureStillImageOutput }

  TAVCaptureCompletionHandler = procedure(const ImageDataSampleBuffer: CMSampleBufferRef;
                                          const Error: NSError) of object;

  // Redeclared the CATransactionClass interface to add the
  // 'captureStillImageAsynchronouslyFromConnection:completionHandler:' selector.
  AVCaptureStillImageOutput = interface(AVCaptureOutput)
    ['{E0B5F87B-AFA2-4AF2-AA36-AA4E5480A9AC}']
    function availableImageDataCVPixelFormatTypes: NSArray; cdecl;
    function availableImageDataCodecTypes: NSArray; cdecl;
    function isCapturingStillImage: Boolean; cdecl;
    function outputSettings: NSDictionary; cdecl;
    procedure setOutputSettings(outputSettings: NSDictionary); cdecl;
    procedure captureStillImageAsynchronouslyFromConnection(connection: AVCaptureConnection;
                                                            completionHandler: TAVCaptureCompletionHandler); cdecl;
  end;
  TAVCaptureStillImageOutput = class(TOCGenericImport<AVCaptureStillImageOutputClass, AVCaptureStillImageOutput>)  end;

  TFMain = class(TForm)
    tbPhone: TToolBar;
    btnPhoneFront: TSpeedButton;
    btnPhoneBack: TSpeedButton;
    btnPhoneSnap: TSpeedButton;
    chkPhoneFaces: TSwitch;
    lblPhoneFaces: TLabel;
    tbPad: TToolBar;
    btnPadFront: TSpeedButton;
    btnPadBack: TSpeedButton;
    btnPadSnap: TSpeedButton;
    chkPadFaces: TSwitch;
    lblPadFaces: TLabel;
    layPhoneFaces: TLayout;
    cpError: TCalloutPanel;
    lblError: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnFrontClick(Sender: TObject);
    procedure btnBackClick(Sender: TObject);
    procedure btnSnapClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure chkFacesSwitch(Sender: TObject);
    procedure FormGesture(Sender: TObject; const EventInfo: TGestureEventInfo;
      var Handled: Boolean);
  private
    { Private declarations }
    FIsUsingFrontFacingCamera: Boolean;
    FVideoCaptureDelegate: TVideoCaptureDelegate;
    FStillImageOutput: AVCaptureStillImageOutput;
    FAVCaptureStillImageIsCapturingStillImageContext: NSString;
    FVideoDataOutput: AVCaptureVideoDataOutput;
    FVideoDataOutputQueue: dispatch_queue_t;
    FEffectiveScale: CGFloat;
    FPreviewArea: CALayer;
    FPreviewLayer: AVCaptureVideoPreviewLayer;
    FFaceDetector: CIDetector;
    FDetectFaces: Boolean;
    FSquare: UIImage;
    FDoingFaceDetection: Boolean;
    FCurDeviceOrientation: UIDeviceOrientation;
    FDestinationData: CFMutableDataRef;
    FLastDistance: Single;
    FSetupDone: Boolean;
    procedure SetupAvCapture;
    procedure TeardownAVCapture;
    procedure ObserveValueForKeyPath(keyPath: NSString; ofObject: Pointer; change: NSDictionary; context: Pointer);
    procedure captureOutput(captureOutput: AVCaptureOutput; didOutputSampleBuffer: CMSampleBufferRef; fromConnection: AVCaptureConnection);
    procedure DrawFaceBoxesForFeatures(Features: NSArray; Clap: CGRect; Orientation: UIDeviceOrientation);
    function VideoPreviewBoxForGravity(Gravity: NSString; FrameSize: CGSize; ApertureSize: CGSize): CGRect;
    procedure SwitchCameras(FrontFacingCamera: Boolean);
    procedure ToggleFaceDetection(DetectFaces: Boolean);
    procedure TakePicture;
    function OrientationForDeviceOrientation(DeviceOrientation: UIDeviceOrientation): AVCaptureVideoOrientation;
    procedure StillImageCaptured(const ImageDataSampleBuffer: CMSampleBufferRef; const Error: NSError);
{$IFNDEF CALLBACK_ERRORS}
    procedure DisplayErrorOnMainQueue(Error: NSError; const Title: String);
{$ENDIF}
    function CreateCGImageFromCVPixelBuffer(PixelBuffer: CVPixelBufferRef; var ImageOut: CGImageRef): OSStatus;
    function NewSquareOverlayedImageForFeatures(Features: NSArray; BackgroundImage: CGImageRef; Orientation: UIDeviceOrientation; IsFrontFacing: Boolean): CGImageRef;
    function WriteCGImageToCameraRoll(Image: CGImageRef; Metadata: NSDictionary): Boolean;
    procedure WriteToPhotosCompletion(assetURL: NSURL; error: NSError);
    procedure WriteToCameraRollCompletion(assetURL: NSURL; error: NSError);
  public
    { Public declarations }
  end;

  dispatch_work_t = reference to procedure;
  dispatch_function_t = procedure(context: Pointer); cdecl;

procedure dispatch_async_f(queue: dispatch_queue_t; context: Pointer; work: dispatch_function_t); cdecl; external libdispatch name _PU + 'dispatch_async_f';
procedure dispatch_async(queue: dispatch_queue_t; work: dispatch_work_t);
procedure dispatch_sync_f(queue: dispatch_queue_t; context: Pointer; work: dispatch_function_t); cdecl; external libdispatch name _PU + 'dispatch_sync_f';
procedure dispatch_sync(queue: dispatch_queue_t; work: dispatch_work_t);
function dispatch_get_main_queue: dispatch_queue_t;

// Definimos esta función porque no está definida en iOSapi.UIKit
procedure UIGraphicsBeginImageContext(size: CGSize); cdecl; external libUIKit name _PU + 'UIGraphicsBeginImageContext';

const
  libImageIO = '/System/Library/Frameworks/ImageIO.framework/ImageIO';

// Definimos estas funciones porque no está accesible Macapi.ImageIO para iOS en Delphi XE5
function CGImageDestinationCreateWithData(data: CFMutableDataRef; type_: CFStringRef; count: Longword; options: CFDictionaryRef): CGImageDestinationRef; cdecl; external libImageIO name _PU + 'CGImageDestinationCreateWithData';
procedure CGImageDestinationAddImage(idst: CGImageDestinationRef; image: CGImageRef; properties: CFDictionaryRef); cdecl; external libImageIO name _PU + 'CGImageDestinationAddImage';
function CGImageDestinationFinalize(idst: CGImageDestinationRef): Integer; cdecl; external libImageIO name _PU + 'CGImageDestinationFinalize';

var
  FMain: TFMain;

implementation

uses Math, Macapi.ObjCRuntime, iOSapi.CoreVideo, FMX.Platform.iOS,
  iOSapi.AssetsLibrary, FMX.Helpers.iOS
{$IF defined(IOS) and NOT defined(CPUARM)}
  , Posix.Dlfcn
{$ENDIF}
  ;

{$R *.fmx}

{ ALAssetsLibrary }

// Because of a bug in the XE5 Update2 definition of
// Class definition for ALAssetsLibrary is missing
type
  TALAssetsLibrary = class(TOCGenericImport<ALAssetsLibraryClass, ALAssetsLibrary>)  end;

{ AVCaptureDeviceInput }

// Because of a bug in the XE5 Update2 definition of
// deviceInputWithDevice and initWithDevice methods,
// we redefine here AVCaptureDeviceInput interfaces.
type
  AVCaptureDeviceInputClass = interface(AVCaptureInputClass)
    ['{71E3EB0E-73B3-48C3-AEF4-306F29F39E5B}']
    {class} function deviceInputWithDevice(device: AVCaptureDevice; error: PPointer): Pointer; cdecl;
  end;
  AVCaptureDeviceInput = interface(AVCaptureInput)
    ['{9D2445AE-EFDD-4374-A76D-D5790EDB19F4}']
    function device: AVCaptureDevice; cdecl;
    function initWithDevice(device: AVCaptureDevice; error: PPointer): Pointer; cdecl;
  end;
  TAVCaptureDeviceInput = class(TOCGenericImport<AVCaptureDeviceInputClass, AVCaptureDeviceInput>)  end;

{ GCD implementation }

function dispatch_get_main_queue: dispatch_queue_t;
var
  FwkMod: HMODULE;
begin
  Result := 0;
  FwkMod := LoadLibrary(PWideChar(libdispatch));
  if FwkMod <> 0 then
  begin
    Result := dispatch_queue_t(GetProcAddress(FwkMod, PWideChar('_dispatch_main_q')));
    FreeLibrary(FwkMod);
  end;
end;

procedure DispatchCallback(context: Pointer); cdecl;
var
  CallbackProc: dispatch_work_t absolute context;
begin
  try
    CallbackProc;
  finally
    IInterface(context)._Release;
  end;
end;

procedure dispatch_async(queue: dispatch_queue_t; work: dispatch_work_t);
var
  callback: Pointer absolute work;
begin
  IInterface(callback)._AddRef;
  dispatch_async_f(queue, callback, DispatchCallback);
end;

procedure dispatch_sync(queue: dispatch_queue_t; work: dispatch_work_t);
var
  callback: Pointer absolute work;
begin
  IInterface(callback)._AddRef;
  dispatch_sync_f(queue, callback, DispatchCallback);
end;

{ TVideoCaptureDelegate }

constructor TVideoCaptureDelegate.Create(Main: TFMain);
begin
  inherited Create;
  FMain := Main;
end;

procedure TVideoCaptureDelegate.observeValueForKeyPath(keyPath: NSString; ofObject: Pointer; change: NSDictionary; context: Pointer);
begin
  FMain.ObserveValueForKeyPath(keyPath, ofObject, change, context);
end;

procedure TVideoCaptureDelegate.captureOutput(captureOutput: AVCaptureOutput; didOutputSampleBuffer: CMSampleBufferRef; fromConnection: AVCaptureConnection);
begin
  FMain.CaptureOutput(captureOutput, didOutputSampleBuffer, fromConnection);
end;

procedure TVideoCaptureDelegate.flashAnimationDidStop(animationID: NSString; finished: NSNumber; context: Pointer);
begin
  FFlashView.removeFromSuperview;
  FFlashView.release;
  FFlashView := nil;
end;

procedure TVideoCaptureDelegate.FlashAnimation(Flash: Boolean);
const
   iOS7TitlebarOffset = 20;
var
  Rect: CGRect;
begin
  if Flash then
  begin
    // Do flash bulb like animation
    FFlashView := TUIView.Alloc;
    Rect := WindowHandleToPlatform(FMain.Handle).View.frame;
    if not (TOSVersion.Check(7, 0) or (FMain.BorderStyle = TFmxFormBorderStyle.bsNone)) then
      Rect.origin.y := iOS7TitlebarOffset;
    FFlashView := TUIView.Wrap(FFlashView.initWithFrame(Rect));
    FFlashView.setBackgroundColor(TUIColor.Wrap(TUIColor.OCClass.whiteColor));
    FFlashView.setAlpha(0.0);
    WindowHandleToPlatform(FMain.Handle).View.window.addSubview(FFlashView);
    TUIView.OCClass.beginAnimations(nil, nil);
    try
      TUIView.OCClass.setAnimationDuration(0.2);
      TUIView.OCClass.setAnimationDelegate(GetObjectID);
      FFlashView.setAlpha(1.0);
    finally
      TUIView.OCClass.commitAnimations;
    end;
  end
  else
  begin
    TUIView.OCClass.beginAnimations(nil, nil);
    try
      TUIView.OCClass.setAnimationDuration(0.2);
      TUIView.OCClass.setAnimationDelegate(GetObjectID);
      TUIView.OCClass.setAnimationDidStopSelector(sel_getUid('flashAnimationDidStop:finished:context:'));
      FFlashView.setAlpha(0.0);
    finally
      TUIView.OCClass.commitAnimations;
    end;
  end;
end;

{ TFMain }

procedure TFMain.FormActivate(Sender: TObject);
begin
  if not FSetupDone then
  begin
    try
	    SetupAVCapture;
    except
      on E: Exception do
      begin
        lblError.Text := E.Message;
        cpError.Visible := True;
        tbPhone.Enabled := False;
        tbPad.Enabled := False;
      end;
    end;
    FSetupDone := True;
  end;
end;

procedure TFMain.FormCreate(Sender: TObject);

  function CIDetectorAccuracyLow: Pointer;
  begin
    Result := Pointer(CocoaPointerConst(libCoreImage, 'CIDetectorAccuracyLow')^);
  end;

  function CIDetectorAccuracy: Pointer;
  begin
    Result := Pointer(CocoaPointerConst(libCoreImage, 'CIDetectorAccuracy')^);
  end;

  function CIDetectorTypeFace: NSString;
  begin
    Result := CocoaNSStringConst(libCoreImage, 'CIDetectorTypeFace');
  end;

  function IsTablet: Boolean;
  begin
    Result := TUIDevice.Wrap(TUIDevice.OCClass.currentDevice).userInterfaceIdiom = UIUserInterfaceIdiomPad;
  end;

var
  DetectorOptions: NSDictionary;
  Objects, Keys: array[0..0] of Pointer;
begin
  tbPad.Visible := IsTablet;
  tbPhone.Visible := not tbPad.Visible;
  FVideoCaptureDelegate := TVideoCaptureDelegate.Create(Self);
  FAVCaptureStillImageIsCapturingStillImageContext := NSSTR('AVCaptureStillImageIsCapturingStillImageContext');
  // ARC does not work with iOS native objects in Delphi, since NSStr is created
  // with autorelease, we have to retain to prevent automatic release when we
  // return control to the operating system.
  FAVCaptureStillImageIsCapturingStillImageContext.retain;

	FSquare := TUIImage.Wrap(TUIImage.OCClass.imageNamed(NSSTR('squarePNG')));
  FSquare.retain;
  Objects[0] := CIDetectorAccuracyLow;
  Keys[0] := CIDetectorAccuracy;
	DetectorOptions := TNSDictionary.Wrap(TNSDictionary.Alloc.initWithObjects(@Objects[0], @Keys[0], 1));
	FFaceDetector := TCIDetector.Wrap(TCIDetector.OCClass.detectorOfType(CIDetectorTypeFace, nil, DetectorOptions));
  FFaceDetector.retain;
	DetectorOptions.release;
end;

procedure TFMain.FormDestroy(Sender: TObject);
begin
  FAVCaptureStillImageIsCapturingStillImageContext.release;
	TeardownAVCapture;
	FfaceDetector.release;
	FSquare.release;
end;

procedure TFMain.FormGesture(Sender: TObject;
  const EventInfo: TGestureEventInfo; var Handled: Boolean);
var
  MaxScaleAndCropFactor: CGFloat;
begin
  if TInteractiveGestureFlag.gfBegin in EventInfo.Flags then
    FLastDistance := EventInfo.Distance
  else if not (TInteractiveGestureFlag.gfEnd in EventInfo.Flags) then
  begin
    FEffectiveScale := ((FMain.Width * FEffectiveScale) + (EventInfo.Distance - FLastDistance) * 4.0) / FMain.Width;
    if FEffectiveScale < 1.0 then
      FEffectiveScale := 1.0
    else if FStillImageOutput <> nil then
    begin
      MaxScaleAndCropFactor := FStillImageOutput.connectionWithMediaType(AVMediaTypeVideo).videoMaxScaleAndCropFactor;
      if FEffectiveScale > MaxScaleAndCropFactor then
        FEffectiveScale := MaxScaleAndCropFactor;
    end;
    objc_msgSend(objc_getClass('CATransaction'), sel_getUid('begin'));
    TCATransaction.OCClass.setAnimationDuration(0.025);
    if FPreviewLayer <> nil then
      FPreviewLayer.setAffineTransform(CGAffineTransformMakeScale(FEffectiveScale, FEffectiveScale));
    TCATransaction.OCClass.commit;
    FLastDistance := EventInfo.Distance;
  end;
end;

procedure TFMain.SetupAvCapture;

  function AVCaptureSessionPreset640x480: NSString;
  begin
    Result := CocoaNSStringConst(libAVFoundation, 'AVCaptureSessionPreset640x480');
  end;

  function AVLayerVideoGravityResizeAspect: NSString;
  begin
    Result := CocoaNSStringConst(libAVFoundation, 'AVLayerVideoGravityResizeAspect');
  end;

  procedure CheckError(AnError: Pointer);
  var Error: NSError;
  begin
    if AnError <> nil then
    begin
      Error := TNSError.Wrap(AnError);
      raise Exception.Create(NSStrToStr(Error.localizedDescription));
    end;
  end;

var
  Error: Pointer;
  Session: AVCaptureSession;
  Device: AVCaptureDevice;
  DeviceInput: AVCaptureDeviceInput;
  RGBOutputSettings: NSDictionary;
  RootLayer: CALayer;
  Bounds: CGRect;
begin
  Error := nil;
  Session := TAVCaptureSession.Create;
  if TUIDevice.Wrap(TUIDevice.OCClass.currentDevice).userInterfaceIdiom = UIUserInterfaceIdiomPhone then
    Session.setSessionPreset(AVCaptureSessionPreset640x480)
  else
    Session.setSessionPreset(AVCaptureSessionPresetPhoto);
  // Select a video device, make an input
  Device := TAVCaptureDevice.Wrap(TAVCaptureDevice.OCClass.defaultDeviceWithMediaType(AVMediaTypeVideo));
  DeviceInput := TAVCaptureDeviceInput.Wrap(TAVCaptureDeviceInput.OCClass.deviceInputWithDevice(Device, @Error));
  CheckError(Error);
  // Select a video device, make an input
	if Session.canAddInput(DeviceInput) then
		Session.addInput(DeviceInput)
  else
    raise Exception.Create('Cannod add Video input to AVCaptureSession');
  try
    // Make a still image output
    FStillImageOutput := TAVCaptureStillImageOutput.Create;
    objc_msgSend((FStillImageOutput as ILocalObject).GetObjectID,
                 sel_getUid('addObserver:forKeyPath:options:context:'),
                 FVideoCaptureDelegate.GetObjectID,
                 (NSSTR('capturingStillImage') as ILocalObject).GetObjectID,
                 NSKeyValueObservingOptionNew,
                 (FAVCaptureStillImageIsCapturingStillImageContext as ILocalObject).GetObjectID);
    if Session.canAddOutput(FStillImageOutput) then
      Session.addOutput(FStillImageOutput)
    else
      raise Exception.Create('Cannod add StillImageOutput to AVCaptureSession');
    // Make a video data output
    FVideoDataOutput := TAVCaptureVideoDataOutput.Create;
    // We want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
    RGBOutputSettings := TNSDictionary.Wrap(TNSDictionary.OCClass.dictionaryWithObject(TNSNumber.OCClass.numberWithInt(kCVPixelFormatType_32BGRA), Pointer(kCVPixelBufferPixelFormatTypeKey)));
    FVideoDataOutput.setVideoSettings(RGBOutputSettings);
    FVideoDataOutput.setAlwaysDiscardsLateVideoFrames(True); // discard if the data output queue is blocked (as we process the still image)
    // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    // see the header doc for setSampleBufferDelegate:queue: for more information
    FVideoDataOutputQueue := dispatch_queue_create('VideoDataOutputQueue', dispatch_queue_t(DISPATCH_QUEUE_SERIAL));
    FVideoDataOutput.setSampleBufferDelegate(FVideoCaptureDelegate.GetObjectID, FVideoDataOutputQueue);
    if Session.canAddOutput(FVideoDataOutput) then
      Session.addOutput(FVideoDataOutput)
    else
      raise Exception.Create('Cannod add VideoDataOutput to AVCaptureSession');
    FVideoDataOutput.connectionWithMediaType(AVMediaTypeVideo).setEnabled(False);
    FEffectiveScale := 1.0;
    RootLayer := WindowHandleToPlatform(Handle).View.layer;
    Bounds := RootLayer.bounds;
    Bounds.size.height := Bounds.size.height - tbPad.Height;
    FPreviewArea := TCALayer.Create;
    FPreviewArea.setBackgroundColor(TUIColor.Wrap(TUIColor.OCClass.blackColor).CGColor);
    FPreviewArea.setMasksToBounds(True);
    FPreviewArea.setFrame(Bounds);
    RootLayer.addSublayer(FPreviewArea);
    FPreviewLayer := TAVCaptureVideoPreviewLayer.Wrap(TAVCaptureVideoPreviewLayer.Alloc.initWithSession(Session));
    FPreviewLayer.setBackgroundColor(TUIColor.Wrap(TUIColor.OCClass.blackColor).CGColor);
    FPreviewLayer.setVideoGravity(AVLayerVideoGravityResizeAspect);
    FPreviewLayer.setFrame(Bounds);
    FPreviewArea.addSublayer(FPreviewLayer);
    Session.startRunning;
    Session.release;
  except
    TeardownAVCapture;
    raise;
  end;
end;

procedure TFMain.TeardownAVCapture;
begin
  FVideoDataOutput.release;
  FVideoDataOutput := nil;
  if FVideoDataOutputQueue <> dispatch_queue_t(nil) then
  begin
    dispatch_release(dispatch_object_t(FVideoDataOutputQueue));
    FVideoDataOutputQueue := dispatch_queue_t(nil);
  end;
  if FStillImageOutput <> nil then
  begin
    objc_msgSend((FStillImageOutput as ILocalObject).GetObjectID,
                 sel_getUid('removeObserver:forKeyPath:'),
                 FVideoCaptureDelegate.GetObjectID,
                 (NSStr('capturingStillImage') as ILocalObject).GetObjectID);
    FStillImageOutput.release;
    FStillImageOutput := nil;
  end;
  if FPreviewLayer <> nil then
  begin
    FPreviewLayer.removeFromSuperlayer;
    FPreviewLayer.release;
    FPreviewLayer := nil;
  end;
  if FPreviewArea <> nil then
  begin
    FPreviewArea.removeFromSuperlayer;
    FPreviewArea.release;
    FPreviewArea := nil;
  end;
end;

procedure TFMain.ObserveValueForKeyPath(keyPath: NSString; ofObject: Pointer; change: NSDictionary; context: Pointer);

  function NSKeyValueChangeNewKey: NSString;
  begin
    Result := CocoaNSStringConst(libFoundation, 'NSKeyValueChangeNewKey');
  end;

var
  IsCapturingStillImage: Boolean;
begin
  if Context = (FAVCaptureStillImageIsCapturingStillImageContext as ILocalObject).GetObjectID then
  begin
    IsCapturingStillImage := objc_msgSend(change.objectForKey((NSKeyValueChangeNewKey as ILocalObject).GetObjectID), sel_getUid('boolValue')) <> nil;
    FVideoCaptureDelegate.FlashAnimation(IsCapturingStillImage);
  end;
end;

procedure TFMain.btnBackClick(Sender: TObject);
begin
  SwitchCameras(False);
end;

procedure TFMain.btnFrontClick(Sender: TObject);
begin
  SwitchCameras(True);
end;

procedure TFMain.btnSnapClick(Sender: TObject);
begin
  TakePicture;
end;

function CIDetectorImageOrientation: Pointer;
begin
  Result := Pointer(CocoaPointerConst(libCoreImage, 'CIDetectorImageOrientation')^);
end;

procedure TFMain.CaptureOutput(captureOutput: AVCaptureOutput; didOutputSampleBuffer: CMSampleBufferRef; fromConnection: AVCaptureConnection);

const
  PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1; //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
  PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2; //   2  =  0th row is at the top, and 0th column is on the right.
  PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT  = 3; //   3  =  0th row is at the bottom, and 0th column is on the right.
  PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT   = 4; //   4  =  0th row is at the bottom, and 0th column is on the left.
  PHOTOS_EXIF_0ROW_LEFT_0COL_TOP      = 5; //   5  =  0th row is on the left, and 0th column is the top.
  PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP     = 6; //   6  =  0th row is on the right, and 0th column is the top.
  PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM  = 7; //   7  =  0th row is on the right, and 0th column is the bottom.
  PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM   = 8; //   8  =  0th row is on the left, and 0th column is the bottom.

var
  PixelBuffer: CVPixelBufferRef;
  Attachments: CFDictionaryRef;
  Image: CIImage;
  ImageOptions: NSDictionary;
  CurDeviceOrientation: UIDeviceOrientation;
  ExifOrientation: Integer;
  Features: NSArray;
  FmtDesc: CMFormatDescriptionRef;
  Clap: CGRect;
begin
	// Got an image
  PixelBuffer := CMSampleBufferGetImageBuffer(didOutputSampleBuffer);
  Attachments := CMCopyDictionaryOfAttachments(kCFAllocatorDefault, didOutputSampleBuffer, kCMAttachmentMode_ShouldPropagate);
  Image := TCIImage.Alloc;
  Image := TCIImage.Wrap(Image.initWithCVPixelBuffer(PixelBuffer, TNSDictionary.Wrap(Attachments)));
  if Attachments <> nil then
		CFRelease(Attachments);
  ImageOptions := nil;
  CurDeviceOrientation := TUIDevice.Wrap(TUIDevice.OCClass.currentDevice).orientation;
  // kCGImagePropertyOrientation values
  //  The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
  //  by the TIFF and EXIF specifications -- see enumeration of integer constants.
  //  The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
  //
  //  used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
  //  If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image.

  case CurDeviceOrientation of
		UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
			ExifOrientation := PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
		UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
			if FIsUsingFrontFacingCamera then
				ExifOrientation := PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT
			else
				ExifOrientation := PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
		UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
			if FIsUsingFrontFacingCamera then
				ExifOrientation := PHOTOS_EXIF_0ROW_TOP_0COL_LEFT
			else
				ExifOrientation := PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
		else
			ExifOrientation := PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
  end;

	ImageOptions := TNSDictionary.Wrap(TNSDictionary.OCClass.dictionaryWithObject(TNSNumber.OCClass.numberWithInt(ExifOrientation), CIDetectorImageOrientation));
  Features := FFaceDetector.featuresInImage(Image, ImageOptions);
  Features.retain; // ARC does not operate in delphi with Objective C objects. Must be done manually
  Image.release;
  // Get the clean aperture
  // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
  // that represents image data valid for display.
	FmtDesc := CMSampleBufferGetFormatDescription(didOutputSampleBuffer);
	Clap := CMVideoFormatDescriptionGetCleanAperture(FmtDesc, False {originIsTopLeft == false});
	dispatch_async(dispatch_get_main_queue,
                 procedure begin
                   DrawFaceBoxesForFeatures(Features, Clap, CurDeviceOrientation);
                 end);
end;

procedure TFMain.chkFacesSwitch(Sender: TObject);
begin
  ToggleFaceDetection((Sender as TSwitch).IsChecked);
end;

// Called asynchronously as the capture output is capturing sample buffers, this method asks the face detector (if on)
// to detect features and for each draw the red square in a layer and set appropriate orientation
procedure TFMain.DrawFaceBoxesForFeatures(Features: NSArray; Clap: CGRect; Orientation: UIDeviceOrientation);

  function kCATransactionDisableActions: NSString;
  begin
    Result := CocoaNSStringConst(libQuartzCore, 'kCATransactionDisableActions');
  end;

var
  Sublayers: NSArray;
  SublayersCount, CurrentSublayer: NSInteger;
  FeaturesCount: NSInteger;
  Idx: NSInteger;
  Layer: CALayer;
  ParentFrameSize: CGSize;
  Gravity: NSString;
  IsMirrored: Boolean;
  PreviewBox: CGRect;
  FF: CIFaceFeature;
  FaceRect: CGRect;
  Temp: CGFloat;
  WidthScaleBy: CGFloat;
  HeightScaleBy: CGFloat;
  FeatureLayer: CALayer;
  CurrentLayer: CALayer;
  LName: NSString;
begin
  try
    Sublayers := TNSArray.Wrap(TNSArray.OCClass.arrayWithArray(FPreviewLayer.sublayers));
    SublayersCount := Sublayers.count;
    CurrentSublayer := 0;
    FeaturesCount := Features.count;

    objc_msgSend(objc_getClass('CATransaction'), sel_getUid('begin'));
    TCATransaction.OCClass.setValue(kCFBooleanTrue, kCATransactionDisableActions);

    // hide all the face layers
    for Idx := 0 to SublayersCount - 1 do
    begin
      Layer := TCALayer.Wrap(Sublayers.objectAtIndex(Idx));
      LName := Layer.name;
      if LName <> nil then
        if LName.isEqualToString(NSSTR('FaceLayer')) then
          Layer.setHidden(True);
    end;

    if (FeaturesCount = 0) or not FDetectFaces then
    begin
      TCATransaction.OCClass.commit;
      Exit; // Early exit
    end;

    ParentFrameSize := WindowHandleToPlatform(Handle).View.frame.size;
    ParentFrameSize.height := ParentFrameSize.height - tbPad.Height;
    Gravity := FPreviewLayer.videoGravity;
    IsMirrored := FPreviewLayer.isMirrored;
    PreviewBox := VideoPreviewBoxForGravity(Gravity, ParentFrameSize, Clap.size);

    for Idx := 0 to FeaturesCount - 1 do
    begin
      // Find the correct position for the square layer within the previewLayer
      // the feature box originates in the bottom left of the video frame.
      // (Bottom right if mirroring is turned on)
      FF := TCIFaceFeature.Wrap(Features.objectAtIndex(Idx));
      FaceRect := FF.bounds;

      // Flip preview width and height
      Temp := FaceRect.size.width;
      FaceRect.size.width := FaceRect.size.height;
      FaceRect.size.height := temp;
      Temp := FaceRect.origin.x;
      FaceRect.origin.x := faceRect.origin.y;
      FaceRect.origin.y := temp;
      // Scale coordinates so they fit in the preview box, which may be scaled
      WidthScaleBy := PreviewBox.size.width / Clap.size.height;
      HeightScaleBy := PreviewBox.size.height / Clap.size.width;
      FaceRect.size.width := FaceRect.size.width * WidthScaleBy;
      FaceRect.size.height := FaceRect.size.height * HeightScaleBy;
      FaceRect.origin.x := FaceRect.origin.x * WidthScaleBy;
      FaceRect.origin.y := FaceRect.origin.y * HeightScaleBy;

      if IsMirrored then
        FaceRect := CGRectOffset(FaceRect, PreviewBox.origin.x + PreviewBox.size.width - FaceRect.size.width - (FaceRect.origin.x * 2), PreviewBox.origin.y)
      else
        FaceRect := CGRectOffset(FaceRect, PreviewBox.origin.x, PreviewBox.origin.y);

      FeatureLayer := nil;

      // Re-use an existing layer if possible
      while (FeatureLayer = nil) and (CurrentSublayer < SublayersCount) do
      begin
        CurrentLayer := TCALayer.Wrap(Sublayers.objectAtIndex(CurrentSublayer));
        Inc(CurrentSublayer);
        LName := CurrentLayer.name;
        if LName <> nil then
          if LName.isEqualToString(NSSTR('FaceLayer')) then
          begin
            FeatureLayer := CurrentLayer;
            CurrentLayer.setHidden(False);
          end;
      end;

      // Create a new one if necessary
      if FeatureLayer = nil then
      begin
        FeatureLayer := TCALayer.Create;
        FeatureLayer.setContents(FSquare.CGImage);
        FeatureLayer.setName(NSSTR('FaceLayer'));
        FPreviewLayer.addSublayer(FeatureLayer);
        FeatureLayer.release;
      end;
      FeatureLayer.setFrame(FaceRect);

      case Orientation of
        UIDeviceOrientationPortrait:
          FeatureLayer.setAffineTransform(CGAffineTransformMakeRotation(DegToRad(0.0)));
        UIDeviceOrientationPortraitUpsideDown:
          FeatureLayer.setAffineTransform(CGAffineTransformMakeRotation(DegToRad(180.0)));
        UIDeviceOrientationLandscapeLeft:
          FeatureLayer.setAffineTransform(CGAffineTransformMakeRotation(DegToRad(90.0)));
        UIDeviceOrientationLandscapeRight:
          FeatureLayer.setAffineTransform(CGAffineTransformMakeRotation(DegToRad(-90.0)));
      end;
    end;
    TCATransaction.OCClass.commit;
  finally
    Features.release; // ARC does not operate in delphi with Objective C objects. Must be done manually
  end;
end;

// Find where the video box is positioned within the preview layer based on the video size and gravity
function TFMain.VideoPreviewBoxForGravity(Gravity: NSString; FrameSize: CGSize; ApertureSize: CGSize): CGRect;

  function AVLayerVideoGravityResizeAspectFill: NSString;
  begin
    Result := CocoaNSStringConst(libAVFoundation, 'AVLayerVideoGravityResizeAspectFill');
  end;

  function AVLayerVideoGravityResizeAspect: NSString;
  begin
    Result := CocoaNSStringConst(libAVFoundation, 'AVLayerVideoGravityResizeAspect');
  end;

  function AVLayerVideoGravityResize: NSString;
  begin
    Result := CocoaNSStringConst(libAVFoundation, 'AVLayerVideoGravityResizeAspect');
  end;

const
  CGSizeZero: CGSize = (width: 0.0; height: 0.0);
var
  ApertureRatio: CGFloat;
  ViewRatio: CGFloat;
  Size: CGSize;
  VideoBox: CGRect;
begin
  ApertureRatio := ApertureSize.height / ApertureSize.width;
  ViewRatio := FrameSize.width / FrameSize.height;

  Size := CGSizeZero;
  if Gravity.isEqualToString(AVLayerVideoGravityResizeAspectFill) then
    if ViewRatio > ApertureRatio then
    begin
      Size.width := FrameSize.width;
      Size.height := ApertureSize.width * (FrameSize.width / ApertureSize.height);
    end
    else
    begin
      Size.width := ApertureSize.height * (FrameSize.height / ApertureSize.width);
      Size.height := frameSize.height;
    end
  else if Gravity.isEqualToString(AVLayerVideoGravityResizeAspect) then
    if ViewRatio > ApertureRatio then
    begin
      Size.width := ApertureSize.height * (FrameSize.height / ApertureSize.width);
      Size.height := FrameSize.height;
    end
    else
    begin
      Size.width := FrameSize.width;
      Size.height := ApertureSize.width * (FrameSize.width / ApertureSize.height);
    end
  else if Gravity.isEqualToString(AVLayerVideoGravityResize) then
  begin
    Size.width := FrameSize.width;
    Size.height := FrameSize.height;
  end;

	VideoBox.size := size;
	if Size.width < FrameSize.width then
		VideoBox.origin.x := (FrameSize.width - Size.width) / 2.0
	else
		VideoBox.origin.x := (Size.width - FrameSize.width) / 2.0;

	if Size.height < FrameSize.height then
		VideoBox.origin.y := (FrameSize.height - Size.height) / 2.0
	else
		VideoBox.origin.y := (Size.height - FrameSize.height) / 2.0;

	Result := VideoBox;
end;

// Use front/back camera
procedure TFMain.SwitchCameras(FrontFacingCamera: Boolean);
var
  DesiredPosition: AVCaptureDevicePosition;
  Devices: NSArray;
  Device: AVCaptureDevice;
  I, J: NSInteger;
  OldInputs: NSArray;
  Input, OldInput: AVCaptureDeviceInput;
begin
  if FIsUsingFrontFacingCamera <> FrontFacingCamera then
  begin
    if FIsUsingFrontFacingCamera then
      DesiredPosition := AVCaptureDevicePositionBack
    else
      DesiredPosition := AVCaptureDevicePositionFront;

    Devices := TAVCaptureDevice.OCClass.devicesWithMediaType(AVMediaTypeVideo);
    for I := 0 to NSInteger(Devices.count) - 1 do
    begin
      Device := TAVCaptureDevice.Wrap(Devices.objectAtIndex(I));
      if Device.position = DesiredPosition then
      begin
        FPreviewLayer.session.beginConfiguration;
        try
          Input := TAVCaptureDeviceInput.Wrap(TAVCaptureDeviceInput.OCClass.deviceInputWithDevice(Device, nil));
          OldInputs := FPreviewLayer.session.inputs;
          for J := 0 to NSInteger(OldInputs.count) - 1 do
          begin
            OldInput := TAVCaptureDeviceInput.Wrap(OldInputs.objectAtIndex(J));
            FPreviewLayer.session.removeInput(OldInput);
          end;
          FPreviewLayer.session.addInput(Input);
        finally
          FPreviewLayer.session.commitConfiguration;
        end;
        Break;
      end;
    end;
    FIsUsingFrontFacingCamera := not FIsUsingFrontFacingCamera;
  end;
end;

// Turn on/off face detection
procedure TFMain.ToggleFaceDetection(DetectFaces: Boolean);
const
  CGRectZero: CGRect =
    (
      origin: (x: 0.0; y: 0.0);
      size: (width: 0.0; height: 0.0)
    );

begin
  FDetectFaces := DetectFaces;
  FVideoDataOutput.connectionWithMediaType(AVMediaTypeVideo).setEnabled(FDetectFaces);
  if not FDetectFaces then
    dispatch_async(dispatch_get_main_queue,
                   procedure begin
                     // Clear out any squares currently displaying.
                     DrawFaceBoxesForFeatures(TNSArray.Create, CGRectZero, UIDeviceOrientationPortrait);
                   end);

end;

// Main action method to take a still image -- if face detection has been turned on and a face has been detected
// the square overlay will be composited on top of the captured image and saved to the camera roll
procedure TFMain.TakePicture;

  function AVVideoCodecJPEG: Pointer;
  begin
    Result := Pointer(CocoaPointerConst(libAVFoundation, 'AVVideoCodecJPEG')^);
  end;

  function AVVideoCodecKey: Pointer;
  begin
    Result := Pointer(CocoaPointerConst(libAVFoundation, 'AVVideoCodecKey')^);
  end;

var
  StillImageConnection: AVCaptureConnection;
  CaptureOrientation: AVCaptureVideoOrientation;
  OutputSettings: NSDictionary;
begin
	// Find out the current orientation and tell the still image output.
  StillImageConnection := FStillImageOutput.connectionWithMediaType(AVMediaTypeVideo);
  FCurDeviceOrientation := TUIDevice.Wrap(TUIDevice.OCClass.currentDevice).orientation;
  CaptureOrientation := OrientationForDeviceOrientation(FCurDeviceOrientation);
  StillImageConnection.setVideoOrientation(CaptureOrientation);
	StillImageConnection.setVideoScaleAndCropFactor(FEffectiveScale);

  FDoingFaceDetection := FDetectFaces and (FEffectiveScale = 1.0);

  // Set the appropriate pixel format / image type output setting depending on if we'll need an uncompressed image for
  // the possiblity of drawing the red square over top or if we're just writing a jpeg to the camera roll which is the trival case
  if FDoingFaceDetection then
    OutputSettings := TNSDictionary.Wrap(TNSDictionary.OCClass.dictionaryWithObject(TNSNumber.OCClass.numberWithInt(kCMPixelFormat_32BGRA),
                                                                                    kCVPixelBufferPixelFormatTypeKey))
  else
    OutputSettings := TNSDictionary.Wrap(TNSDictionary.OCClass.dictionaryWithObject(AVVideoCodecJPEG, AVVideoCodecKey));
  FStillImageOutput.setOutputSettings(OutputSettings);

  FStillImageOutput.captureStillImageAsynchronouslyFromConnection(StillImageConnection, StillImageCaptured);
end;

procedure TFMain.StillImageCaptured(const ImageDataSampleBuffer: CMSampleBufferRef; const Error: NSError);

  function kCGImagePropertyOrientation: CFStringRef;
  begin
    Result := CFStringRef(CocoaPointerConst(libImageIO, 'kCGImagePropertyOrientation')^);
  end;

var
  PixelBuffer: CVPixelBufferRef;
  Attachments: CFDictionaryRef;
  Image: CIImage;
  ImageOptions: NSDictionary;
  Orientation: Pointer;
  JpegData: NSData;
  Lib: ALAssetsLibrary;
begin
{$IFNDEF CALLBACK_ERRORS}
  if Error <> nil then
    DisplayErrorOnMainQueue(Error, 'Take picture failed')
  else
{$ELSE}
  if ImageDataSampleBuffer <> nil then
{$ENDIF}
  if FDoingFaceDetection then
  begin
    // Got an image.
    PixelBuffer := CMSampleBufferGetImageBuffer(ImageDataSampleBuffer);
    Attachments := CMCopyDictionaryOfAttachments(kCFAllocatorDefault, ImageDataSampleBuffer, kCMAttachmentMode_ShouldPropagate);
    Image := TCIImage.Wrap(TCIImage.Alloc.initWithCVPixelBuffer(PixelBuffer, TNSDictionary.Wrap(Attachments)));
    if Attachments <> nil then
      CFRelease(Attachments);

    Orientation := CMGetAttachment(ImageDataSampleBuffer, kCGImagePropertyOrientation, nil);
    if Orientation <> nil then
    begin
      ImageOptions :=  TNSDictionary.Wrap(TNSDictionary.OCClass.dictionaryWithObject(Orientation, CIDetectorImageOrientation));
      ImageOptions.retain;
    end
    else
      ImageOptions := nil;

    // When processing an existing frame we want any new frames to be automatically dropped
    // queueing this block to execute on the videoDataOutputQueue serial queue ensures this
    // see the header doc for setSampleBufferDelegate:queue: for more information
    dispatch_sync(FVideoDataOutputQueue,
                  procedure
                  var
                    Features: NSArray;
                    SrcImage: CGImageRef;
                    Err: OSStatus;
                    ImageResult: CGImageRef;
                    Attachments: CFDictionaryRef;
                  begin
                    // Get the array of CIFeature instances in the given image with a orientation passed in
                    // the detection will be done based on the orientation but the coordinates in the returned features will
                    // still be based on those of the image.
                    Features := FFaceDetector.featuresInImage(Image, ImageOptions);
                    if ImageOptions <> nil then
                      ImageOptions.release;
                    SrcImage := nil;
                    Err := CreateCGImageFromCVPixelBuffer(CMSampleBufferGetImageBuffer(ImageDataSampleBuffer), SrcImage);
                    Assert(Err = noErr, 'CreateCGImageFromCVPixelBuffer error');

                    ImageResult := NewSquareOverlayedImageForFeatures(Features, SrcImage, FCurDeviceOrientation, FIsUsingFrontFacingCamera);

                    if SrcImage <> nil then
                      CFRelease(SrcImage);

                    Attachments := CMCopyDictionaryOfAttachments(kCFAllocatorDefault, ImageDataSampleBuffer, kCMAttachmentMode_ShouldPropagate);
                    WriteCGImageToCameraRoll(ImageResult, TNSDictionary.Wrap(Attachments));
                    if Attachments <> nil then
                      CFRelease(Attachments);
                    if ImageResult <> nil then
                      CFRelease(ImageResult);
                  end);
    Image.release;
  end
  else
  begin
    // Trivial simple JPEG case
    JpegData := TAVCaptureStillImageOutput.OCClass.jpegStillImageNSDataRepresentation(ImageDataSampleBuffer);
    Attachments := CMCopyDictionaryOfAttachments(kCFAllocatorDefault, ImageDataSampleBuffer, kCMAttachmentMode_ShouldPropagate);
    Lib := TALAssetsLibrary.Create;
    Lib.writeImageDataToSavedPhotosAlbum(JpegData, TNSDictionary.Wrap(Attachments), WriteToPhotosCompletion);
    if Attachments <> nil then
      CFRelease(Attachments);
    Lib.release;
  end;
end;

procedure TFMain.WriteToPhotosCompletion(assetURL: NSURL; error: NSError);
begin
{$IFNDEF CALLBACK_ERRORS}
  if error <> nil then
    DisplayErrorOnMainQueue(error, 'Save to camera roll failed');
{$ENDIF}
end;

function TFMain.OrientationForDeviceOrientation(DeviceOrientation: UIDeviceOrientation): AVCaptureVideoOrientation;
begin
  Result := DeviceOrientation;
  if DeviceOrientation = UIDeviceOrientationLandscapeLeft then
    Result := AVCaptureVideoOrientationLandscapeRight
  else if DeviceOrientation = UIDeviceOrientationLandscapeRight then
    Result := AVCaptureVideoOrientationLandscapeLeft;
end;

{$IFNDEF CALLBACK_ERRORS}
procedure TFMain.DisplayErrorOnMainQueue(Error: NSError; const Title: String);
begin
  Error.retain;
  dispatch_async(dispatch_get_main_queue,
                 procedure
                 var
                   AlertView: UIAlertView;
                 begin
                   AlertView := TUIAlertView.Wrap(TUIAlertView.Alloc.initWithTitle(NSSTR(Format('%s (%d)', [Title, Integer(Error.code)])),
                                                                                   Error.localizedDescription,
                                                                                   nil,
                                                                                   NSSTR('Dimiss'),
                                                                                   nil));
                   Error.release;
                   AlertView.show;
                   AlertView.release;
                 end);
end;
{$ENDIF}

procedure ReleaseCVPixelBuffer(Pixel, Data: Pointer; Size: size_t); cdecl;
var
  PixelBuffer: CVPixelBufferRef;
begin
  PixelBuffer := CVPixelBufferRef(Pixel);
  CVPixelBufferUnlockBaseAddress(PixelBuffer, 0);
	CVPixelBufferRelease(PixelBuffer);
end;

function TFMain.CreateCGImageFromCVPixelBuffer(PixelBuffer: CVPixelBufferRef; var ImageOut: CGImageRef): OSStatus;
var
	Err: OSStatus;
	SourcePixelFormat: OSType;
	Width, Height, SourceRowBytes: size_t;
	SourceBaseAddr: Pointer;
	BitmapInfo: CGBitmapInfo;
	ColorSpace: CGColorSpaceRef;
	Provider: CGDataProviderRef;
	Image: CGImageRef;
begin
	Err := noErr;

	SourcePixelFormat := CVPixelBufferGetPixelFormatType(PixelBuffer);
	if kCVPixelFormatType_32ARGB = sourcePixelFormat then
		BitmapInfo := kCGBitmapByteOrder32Big or kCGImageAlphaNoneSkipFirst
	else if kCVPixelFormatType_32BGRA = sourcePixelFormat then
		BitmapInfo := kCGBitmapByteOrder32Little or kCGImageAlphaNoneSkipFirst
	else
		Exit(-95014); // Only uncompressed pixel formats

	SourceRowBytes := CVPixelBufferGetBytesPerRow(PixelBuffer);
	Width := CVPixelBufferGetWidth(PixelBuffer);
	Height := CVPixelBufferGetHeight(PixelBuffer);

	CVPixelBufferLockBaseAddress(PixelBuffer, 0);
	SourceBaseAddr := CVPixelBufferGetBaseAddress(PixelBuffer);

  ColorSpace := CGColorSpaceCreateDeviceRGB;

	CVPixelBufferRetain(PixelBuffer);
	Provider := CGDataProviderCreateWithData(Pointer(PixelBuffer), SourceBaseAddr, SourceRowBytes * Height, ReleaseCVPixelBuffer);
	Image := CGImageCreate(Width, Height, 8, 32, SourceRowBytes, ColorSpace, BitmapInfo, Provider, nil, 1, kCGRenderingIntentDefault);
  if (Err <> noErr) and (Image <> nil) then
  begin
    CGImageRelease(Image);
    Image := nil;
  end;
	if Provider <> nil then
    CGDataProviderRelease(Provider);
	if ColorSpace <> nil then
    CGColorSpaceRelease(ColorSpace);
	ImageOut := Image;
	Result := Err;
end;

// Utility routine to create a new image with the red square overlay with appropriate orientation
// and return the new composited image which can be saved to the camera roll
function TFMain.NewSquareOverlayedImageForFeatures(Features: NSArray; BackgroundImage: CGImageRef;
                                                   Orientation: UIDeviceOrientation; IsFrontFacing: Boolean): CGImageRef;

  // Utility used by newSquareOverlayedImageForFeatures for
  function CreateCGBitmapContextForSize(Size: CGSize): CGContextRef;
  var
    Context: CGContextRef;
    ColorSpace: CGColorSpaceRef;
    BitmapBytesPerRow: Integer;
  begin
    BitmapBytesPerRow := Round(Size.width) * 4;

    ColorSpace := CGColorSpaceCreateDeviceRGB();
    Context := CGBitmapContextCreate (nil,
                                      Round(Size.width),
                                      Round(Size.height),
                                      8, // Bits per component
                                      BitmapBytesPerRow,
                                      ColorSpace,
                                      kCGImageAlphaPremultipliedLast);
    CGContextSetAllowsAntialiasing(Context, 0);
    CGColorSpaceRelease(ColorSpace);
    Result := Context;
  end;

  function imageRotatedByDegrees(Image: UIImage; Degrees: CGFloat): UIImage;
  var
    RotatedViewBox: UIView;
    T: CGAffineTransform;
    RotatedSize: CGSize;
    Bitmap: CGContextRef;
  begin
    // Calculate the size of the rotated view's containing box for our drawing space
    RotatedViewBox := TUIView.Wrap(TUIView.Alloc.initWithFrame(CGRectMake(0, 0, Image.size.width, Image.size.height)));
    T := CGAffineTransformMakeRotation(DegToRad(Degrees));
    RotatedViewBox.setTransform(T);
    RotatedSize := RotatedViewBox.frame.size;
    RotatedViewBox.release;

    // Create the bitmap context
    UIGraphicsBeginImageContext(RotatedSize);
    Bitmap := UIGraphicsGetCurrentContext();

    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(Bitmap, RotatedSize.width / 2.0, RotatedSize.height / 2.0);

    // Rotate the image context
    CGContextRotateCTM(Bitmap, DegToRad(Degrees));

    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(Bitmap, 1.0, -1.0);
    CGContextDrawImage(Bitmap, CGRectMake(-Image.size.width / 2.0, -Image.size.height / 2.0, Image.size.width, Image.size.height), Image.CGImage);

    Result := TUIImage.Wrap(UIGraphicsGetImageFromCurrentImageContext);
    UIGraphicsEndImageContext;
  end;

var
	BackgroundImageRect: CGRect;
	BitmapContext: CGContextRef;
	RotationDegrees: CGFloat;
  RotatedSquareImage: UIImage;
  I: Integer;
  FF: CIFaceFeature;
  FaceRect: CGRect;
begin
	BackgroundImageRect := CGRectMake(0.0, 0.0, CGImageGetWidth(BackgroundImage), CGImageGetHeight(BackgroundImage));
	BitmapContext := CreateCGBitmapContextForSize(BackgroundImageRect.size);
	CGContextClearRect(BitmapContext, backgroundImageRect);
	CGContextDrawImage(BitmapContext, BackgroundImageRect, BackgroundImage);
	RotationDegrees := 0.0;

	case Orientation of
		UIDeviceOrientationPortrait:
			RotationDegrees := -90.0;
		UIDeviceOrientationPortraitUpsideDown:
			RotationDegrees := 90.0;
		UIDeviceOrientationLandscapeLeft:
			if IsFrontFacing then
        RotationDegrees := 180.0
			else
        RotationDegrees := 0.0;
		UIDeviceOrientationLandscapeRight:
			if IsFrontFacing then
        RotationDegrees := 0.0
			else
        RotationDegrees := 180.0;
		else
		  ; // Leave the layer in its last known orientation
  end;
	RotatedSquareImage := ImageRotatedByDegrees(FSquare, RotationDegrees);

  // Features found by the face detector
  for I := 0 to NSInteger(Features.count) - 1 do
  begin
    FF := TCIFaceFeature.Wrap(Features.objectAtIndex(I));
    FaceRect := FF.bounds;
    CGContextDrawImage(BitmapContext, FaceRect, RotatedSquareImage.CGImage);
  end;
	Result := CGBitmapContextCreateImage(BitmapContext);
	CGContextRelease(BitmapContext);
end;

// Utility routine used after taking a still image to write the resulting image to the camera roll
function TFMain.WriteCGImageToCameraRoll(Image: CGImageRef; Metadata: NSDictionary): Boolean;

  function kCGImageDestinationLossyCompressionQuality: CFStringRef;
  begin
    Result := CFStringRef(CocoaPointerConst(libImageIO, 'kCGImageDestinationLossyCompressionQuality')^);
  end;

const
	JPEGCompQuality: CGFloat = 0.85; // JPEGHigherQuality
var
	Destination: CGImageDestinationRef;
	Success: Boolean;
	OptionsDict: CFMutableDictionaryRef;
	QualityNum: CFNumberRef;
  Lib: ALAssetsLibrary;
  KC: CFDictionaryKeyCallBacks;
  KV: CFDictionaryValueCallBacks;
begin
	FDestinationData := CFDataCreateMutable(kCFAllocatorDefault, 0);
	Destination := CGImageDestinationCreateWithData(FDestinationData,
																		              CFSTR('public.jpeg'),
																		              1,
																		              nil);
	Success := Destination <> nil;
	if Success then
  begin
	  OptionsDict := nil;

  	QualityNum := CFNumberCreate(nil, kCFNumberFloatType, @JPEGCompQuality);
    if QualityNum <> nil then
    begin
      KC := kCFTypeDictionaryKeyCallBacks;
      KV := kCFTypeDictionaryValueCallBacks;
      OptionsDict := CFDictionaryCreateMutable(nil, 0, @KC, @KV);
      if OptionsDict <> nil then
        CFDictionarySetValue(OptionsDict, kCGImageDestinationLossyCompressionQuality, QualityNum);
      CFRelease(QualityNum);
    end;

    CGImageDestinationAddImage(Destination, Image, CFDictionaryRef(OptionsDict));
    Success := CGImageDestinationFinalize(Destination) <> 0;

    if OptionsDict <> nil then
      CFRelease(OptionsDict);

    if Success then
    begin
      CFRetain(FDestinationData);
      Lib := TALAssetsLibrary.Create;
      Lib.writeImageDataToSavedPhotosAlbum(TNSData.Wrap(FDestinationData), Metadata, WriteToCameraRollCompletion);
      Lib.release;
    end;
  end;
	if FDestinationData <> nil then
		CFRelease(FDestinationData);
	if Destination <> nil then
		CFRelease(Destination);
	Result := Success;
end;

procedure TFMain.WriteToCameraRollCompletion(assetURL: NSURL; error: NSError);
begin
  if FDestinationData <> nil then
    CFRelease(FDestinationData);
end;

{$IF defined(IOS) and NOT defined(CPUARM)}
var
  ALModule: THandle;
{$ELSE}
var
  ALModule: HMODULE;
{$ENDIF IOS}

{$IF defined(IOS) and NOT defined(CPUARM)}
initialization
  ALModule := dlopen(MarshaledAString(libAssetsLibrary), RTLD_LAZY);

finalization
  dlclose(ALModule);
{$ELSE}
initialization
  // Needed to avoid missing Objective C class ALAssetsLibrary error
  ALModule := LoadLibrary(PWideChar(libAssetsLibrary));

finalization
  FreeLibrary(ALModule);
{$ENDIF IOS}
end.

