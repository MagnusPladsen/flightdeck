import Foundation

/// JavaScript for Automation that reads the system now-playing item from MediaRemote once a second
/// and prints one JSON line whenever it changes, plus a heartbeat every ten seconds.
///
/// MediaRemote only answers Apple-signed processes on macOS 15.4 and later, so the app cannot ask it
/// directly. `osascript` is Apple-signed, so it runs this script for the app. The heartbeat makes the
/// script exit on its own (a write to a closed pipe) if the app quits without stopping it.
public enum NowPlayingScript {
    public static let executable = "/usr/bin/osascript"

    public static var arguments: [String] { ["-l", "JavaScript", "-e", source] }

    static let source = """
    ObjC.import('Foundation');
    $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework').load;
    const request = $.NSClassFromString('MRNowPlayingRequest');
    const output = $.NSFileHandle.fileHandleWithStandardOutput;
    const write = line => output.writeData($(line + '\\n').dataUsingEncoding($.NSUTF8StringEncoding));
    const value = (info, key) => {
      const object = info.objectForKey('kMRMediaRemoteNowPlayingInfo' + key);
      return object.isNil() ? null : ObjC.unwrap(object);
    };
    const readEvent = () => {
      const item = request.localNowPlayingItem;
      const info = item.isNil() ? null : item.nowPlayingInfo;
      if (!info || info.isNil() || !value(info, 'Title')) return [{ state: 'none' }, null];
      const client = request.localNowPlayingPlayerPath.client;
      const timestamp = info.objectForKey('kMRMediaRemoteNowPlayingInfoTimestamp');
      return [{
        state: 'track', playing: request.localIsPlaying,
        title: value(info, 'Title'), artist: value(info, 'Artist'), album: value(info, 'Album'),
        duration: value(info, 'Duration'), elapsed: value(info, 'ElapsedTime'), rate: value(info, 'PlaybackRate'),
        timestamp: timestamp.isNil() ? null : timestamp.timeIntervalSince1970, id: value(info, 'ContentItemIdentifier'),
        bundleID: client.isNil() ? null : ObjC.unwrap(client.bundleIdentifier),
        app: client.isNil() ? null : ObjC.unwrap(client.displayName),
        hasArtwork: !info.objectForKey('kMRMediaRemoteNowPlayingInfoArtworkData').isNil()
      }, info];
    };
    let last = '', lastArtworkKey, quietTicks = 0;
    while (true) {
      const [event, info] = readEvent();
      const line = JSON.stringify(event);
      quietTicks += 1;
      if (line !== last) {
        const artworkKey = event.id + ':' + event.hasArtwork;
        if (event.state === 'track' && event.hasArtwork && artworkKey !== lastArtworkKey) {
          const artwork = info.objectForKey('kMRMediaRemoteNowPlayingInfoArtworkData');
          event.artwork = ObjC.unwrap(artwork.base64EncodedStringWithOptions(0));
        }
        lastArtworkKey = artworkKey;
        write(JSON.stringify(event));
        last = line;
        quietTicks = 0;
      } else if (quietTicks >= 10) {
        write('{"state":"heartbeat"}');
        quietTicks = 0;
      }
      delay(1);
    }
    """
}
