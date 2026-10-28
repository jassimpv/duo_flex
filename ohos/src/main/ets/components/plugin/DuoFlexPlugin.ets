import {
  EventChannel,
  EventSink,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  StreamHandler,
} from '@ohos/flutter_ohos';
import { display } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

const METHODS = 'duo_flex/methods';
const HINGE_EVENTS = 'duo_flex/hinge_angle';
const POSTURE_EVENTS = 'duo_flex/fold_posture';
const SCREEN_EVENTS = 'duo_flex/screen_info';
const DISPLAY_EVENTS = 'duo_flex/display_changes';

/** HarmonyOS implementation backed by public display fold APIs. */
export default class DuoFlexPlugin implements FlutterPlugin, MethodCallHandler {
  private methodChannel: MethodChannel | null = null;
  private postureChannel: EventChannel | null = null;
  private displayChannel: EventChannel | null = null;
  private hingeChannel: EventChannel | null = null;
  private screenChannel: EventChannel | null = null;
  private postureHandler: FoldPostureStreamHandler | null = null;
  private displayHandler: FoldDisplayStreamHandler | null = null;

  getUniqueClassName(): string {
    return 'DuoFlexPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    const messenger = binding.getBinaryMessenger();
    this.methodChannel = new MethodChannel(messenger, METHODS);
    this.methodChannel.setMethodCallHandler(this);

    this.postureHandler = new FoldPostureStreamHandler();
    this.postureChannel = new EventChannel(messenger, POSTURE_EVENTS);
    this.postureChannel.setStreamHandler(this.postureHandler);

    this.displayHandler = new FoldDisplayStreamHandler();
    this.displayChannel = new EventChannel(messenger, DISPLAY_EVENTS);
    this.displayChannel.setStreamHandler(this.displayHandler);

    this.hingeChannel = new EventChannel(messenger, HINGE_EVENTS);
    this.hingeChannel.setStreamHandler(new UnsupportedStreamHandler(
      'HarmonyOS does not expose a hinge-angle value through this plugin.',
    ));

    this.screenChannel = new EventChannel(messenger, SCREEN_EVENTS);
    this.screenChannel.setStreamHandler(new UnsupportedStreamHandler(
      'Flutter window geometry is not exposed by the HarmonyOS implementation.',
    ));
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.methodChannel?.setMethodCallHandler(null);
    this.postureChannel?.setStreamHandler(null);
    this.displayChannel?.setStreamHandler(null);
    this.hingeChannel?.setStreamHandler(null);
    this.screenChannel?.setStreamHandler(null);
    this.postureHandler?.dispose();
    this.displayHandler?.dispose();
    this.methodChannel = null;
    this.postureChannel = null;
    this.displayChannel = null;
    this.hingeChannel = null;
    this.screenChannel = null;
    this.postureHandler = null;
    this.displayHandler = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    try {
      switch (call.method) {
        case 'getPlatformVersion':
          result.success('HarmonyOS');
          return;
        case 'getCapabilities':
          result.success(capabilities());
          return;
        case 'getDeviceInfo':
          result.success({
            model: null,
            systemName: 'HarmonyOS',
            systemVersion: null,
            isFoldable: isFoldable(),
          });
          return;
        case 'getScreenInfo':
          result.success(null);
          return;
        case 'getDisplayInfo':
          result.success(displaySnapshot());
          return;
        case 'getDisplayRegions':
          result.success(creaseRegions());
          return;
        case 'getHingeAngle':
          result.success(null);
          return;
        case 'getFoldPosture':
          result.success(foldPosture());
          return;
        default:
          result.notImplemented();
          return;
      }
    } catch (error) {
      const failure = error as BusinessError;
      result.error('NATIVE_OPERATION_FAILED', failure.message, null);
    }
  }
}

function capabilities(): Record<string, boolean> {
  const foldable = isFoldable();
  return {
    supportsHingeAngle: false,
    supportsFoldPosture: foldable === true,
    supportsDisplayRegions: foldable === true,
    supportsDisplayChanges: foldable === true,
    supportsMultipleDisplays: false,
    supportsSafeAreaInsets: false,
  };
}

function isFoldable(): boolean | null {
  try {
    return display.isFoldable();
  } catch (_error) {
    return null;
  }
}

function foldPosture(): string {
  if (isFoldable() !== true) {
    return 'unknown';
  }
  try {
    switch (display.getFoldStatus()) {
      case display.FoldStatus.FOLD_STATUS_EXPANDED:
        return 'fullyOpen';
      case display.FoldStatus.FOLD_STATUS_FOLDED:
        return 'closed';
      case display.FoldStatus.FOLD_STATUS_HALF_FOLDED:
        return 'halfOpen';
      default:
        return 'unknown';
    }
  } catch (_error) {
    return 'unknown';
  }
}

function creaseRegions(): Array<Record<string, Object>> {
  if (isFoldable() !== true) {
    return [];
  }
  try {
    const crease = display.getCurrentFoldCreaseRegion();
    return crease.creaseRects.map((rect, index) => ({
      id: `harmony-fold-crease-${index}`,
      x: rect.left,
      y: rect.top,
      width: rect.width,
      height: rect.height,
      isActive: true,
      type: 'reservedDivision',
    }));
  } catch (_error) {
    return [];
  }
}

function displaySnapshot(): Record<string, Object> {
  const screen = display.getDefaultDisplaySync();
  return {
    identifier: String(screen.id),
    width: screen.width,
    height: screen.height,
    // Regions remain in native display pixels; scale reports the platform's
    // logical-pixel factor when available.
    scale: screen.densityPixels > 0 ? screen.densityPixels : 1,
    isActive: true,
    regions: creaseRegions(),
    displayType: 'builtIn',
  };
}

class FoldPostureStreamHandler implements StreamHandler {
  private sink: EventSink | null = null;
  private callback: ((status: display.FoldStatus) => void) | null = null;

  onListen(_arguments: ESObject, sink: EventSink): void {
    this.sink = sink;
    try {
      this.callback = (_status: display.FoldStatus) => {
        this.sink?.success(foldPosture());
      };
      display.on('foldStatusChange', this.callback);
      sink.success(foldPosture());
    } catch (error) {
      this.stop();
      const failure = error as BusinessError;
      sink.error('FOLD_STATUS_LISTENER_ERROR', failure.message, null);
    }
  }

  onCancel(_arguments: ESObject): void {
    this.stop();
  }

  dispose(): void {
    this.stop();
  }

  private stop(): void {
    if (this.callback !== null) {
      try {
        display.off('foldStatusChange', this.callback);
      } catch (_error) {
        // The engine may already have released the display observer.
      }
      this.callback = null;
    }
    this.sink = null;
  }
}

class FoldDisplayStreamHandler implements StreamHandler {
  private sink: EventSink | null = null;
  private callback: ((status: display.FoldStatus) => void) | null = null;
  private displayCallback: ((displayId: number) => void) | null = null;

  onListen(_arguments: ESObject, sink: EventSink): void {
    this.sink = sink;
    try {
      this.callback = (_status: display.FoldStatus) => {
        this.emitSnapshot();
      };
      display.on('foldStatusChange', this.callback);
      this.displayCallback = (_displayId: number) => this.emitSnapshot();
      display.on('change', this.displayCallback);
      sink.success(displaySnapshot());
    } catch (error) {
      this.stop();
      const failure = error as BusinessError;
      sink.error('DISPLAY_LISTENER_ERROR', failure.message, null);
    }
  }

  onCancel(_arguments: ESObject): void {
    this.stop();
  }

  dispose(): void {
    this.stop();
  }

  private stop(): void {
    if (this.callback !== null) {
      try {
        display.off('foldStatusChange', this.callback);
      } catch (_error) {
        // The engine may already have released the display observer.
      }
      this.callback = null;
    }
    if (this.displayCallback !== null) {
      try {
        display.off('change', this.displayCallback);
      } catch (_error) {
        // The engine may already have released the display observer.
      }
      this.displayCallback = null;
    }
    this.sink = null;
  }

  private emitSnapshot(): void {
    try {
      this.sink?.success(displaySnapshot());
    } catch (error) {
      const failure = error as BusinessError;
      this.sink?.error('DISPLAY_UPDATE_FAILED', failure.message, null);
    }
  }
}

class UnsupportedStreamHandler implements StreamHandler {
  constructor(private readonly message: string) {}

  onListen(_arguments: ESObject, sink: EventSink): void {
    sink.error('UNSUPPORTED_FEATURE', this.message, null);
  }

  onCancel(_arguments: ESObject): void {}
}
