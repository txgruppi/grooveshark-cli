#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "Chrome.h"

ChromeTab *getFirstGroovesharkTab(ChromeApplication *app) {
  for (ChromeWindow *window in [[app windows] get]) {
    for (ChromeTab *tab in [[window tabs] get]) {
      if ([[tab URL] hasPrefix:@"http://grooveshark.com/"]) {
        return tab;
      }
    }
  }
  return nil;
}

NSDictionary *getCurrentSongStatus(ChromeTab *tab) {
  return [tab executeJavascript:@"(function(){ return Grooveshark.getCurrentSongStatus(); })();"];
}

NSString *getPlayStatus(ChromeTab *tab) {
  NSDictionary *result = getCurrentSongStatus(tab);
  return [result objectForKey:@"status"];
}

BOOL isPlaying(ChromeTab *tab) {
  return [getPlayStatus(tab) isEqualToString:@"playing"];
}

BOOL isPaused(ChromeTab *tab) {
  return [getPlayStatus(tab) isEqualToString:@"paused"];
}

void executeNext(ChromeTab *tab) {
  [tab executeJavascript:@"(function(){ return Grooveshark.next(); })();"];
}

void executeMute(ChromeTab *tab) {
  [tab executeJavascript:@"(function(){ return Grooveshark.setIsMuted(true); })();"];
}

void executeUnmute(ChromeTab *tab) {
  [tab executeJavascript:@"(function(){ return Grooveshark.setIsMuted(false); })();"];
}

void executePrevious(ChromeTab *tab) {
  [tab executeJavascript:@"(function(){ return Grooveshark.previous(); })();"];
}

void executeFavorite(ChromeTab *tab) {
  [tab executeJavascript:@"(function(){ return Grooveshark.favoriteCurrentSong(); })();"];
}

void executeVolume(ChromeTab *tab, int volume) {
  if (volume <= 0) {
    volume = -1; // Set volume to -1 if its 0. 0 is buggy
  } else if (volume > 100) {
    volume = 100;
  }
  [tab executeJavascript:[NSString stringWithFormat:@"(function(){ return Grooveshark.setVolume(%d); })();", volume]];
}

void executePlayPause(ChromeTab *tab) {
  [tab executeJavascript:@"(function(){ return Grooveshark.togglePlayPause(); })();"];
}

void usage(char *cmd) {
  printf("Usage: %s <command>\n\n  Commands:\n", cmd);
  printf("    %-28s\n      %s\n", "status|st",                  "Show Grooveshark status and track information");
  printf("    %-28s\n      %s\n", "play|pause|playpause|pp",    "Toggle the playing/paused state of the current track");
  printf("    %-28s\n      %s\n", "next|n",                     "Advance to the next track in the current playlist");
  printf("    %-28s\n      %s\n", "prev|p",                     "Return to the previous track in the current playlist");
  printf("    %-28s\n      %s\n", "mute|m",                     "Mute Grooveshark's volume");
  printf("    %-28s\n      %s\n", "unmute|um",                  "Unmute Grooveshark's volume");
  printf("    %-28s\n      %s\n", "vol up|u",                   "Increase Grooveshark's volume by 10%");
  printf("    %-28s\n      %s\n", "vol down|d",                 "Decrease Grooveshark's volume by 10%");
  printf("    %-28s\n      %s\n", "vol #|v #",                  "Set Grooveshark's volume to # [0-100]");
}

int main(int argc, char *argv[]) {
  ChromeApplication *app = [SBApplication applicationWithBundleIdentifier:@"com.google.Chrome"];

  int cmdFound = 0;

  ChromeTab *tab = getFirstGroovesharkTab(app);

  if (tab == nil) {
    printf("Can't find a Grooveshark tab\n");
    return 1;
  }

  if (argc == 2) {
    if (strcmp(argv[1], "play") == 0 || strcmp(argv[1], "pause") == 0 || strcmp(argv[1], "playpause") == 0 || strcmp(argv[1], "pp") == 0) {
      executePlayPause(tab);
      cmdFound = 1;
    } else if (strcmp(argv[1], "next") == 0 || strcmp(argv[1], "n") == 0) {
      executeNext(tab);
      cmdFound = 1;
    } else if (strcmp(argv[1], "prev") == 0 || strcmp(argv[1], "p") == 0) {
      executePrevious(tab);
      cmdFound = 1;
    } else if (strcmp(argv[1], "mute") == 0 || strcmp(argv[1], "m") == 0) {
      executeMute(tab);
      cmdFound = 1;
    } else if (strcmp(argv[1], "unmute") == 0 || strcmp(argv[1], "um") == 0) {
      executeUnmute(tab);
      cmdFound = 1;
    } else if (strcmp(argv[1], "favorite") == 0 || strcmp(argv[1], "fav") == 0 || strcmp(argv[1], "f") == 0) {
      executeFavorite(tab);
      cmdFound = 1;
    } else if (strcmp(argv[1], "status") == 0 || strcmp(argv[1], "st") == 0) {
      NSDictionary *song = getCurrentSongStatus(tab);
      if (!song) {
        return 0;
      }
      NSString *status = [song objectForKey:@"status"];
      if (status == nil) {
        return 0;
      }
      printf("Grooveshark is %s\n", [status UTF8String]);
      song = [song objectForKey:@"song"];
      if (!song) {
        return 0;
      }
      if ([status isEqualToString:@"playing"] || [status isEqualToString:@"paused"] || [status isEqualToString:@"loading"]) {
        printf("Current track: %s - %s [%.2f of %.2f seconds]\n", [[[song objectForKey:@"artistName"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] UTF8String], [[[song objectForKey:@"songName"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] UTF8String], [[song objectForKey:@"position"] floatValue]/1000, [[song objectForKey:@"calculatedDuration"] floatValue]/1000);
      }
      cmdFound = 1;
    } else if (strcmp(argv[1], "help") == 0 || strcmp(argv[1], "h") == 0) {
      usage(argv[0]);
      return 0;
    }
  } else if (argc == 3) {
    if (strcmp(argv[1], "volume") == 0 || strcmp(argv[1], "vol") == 0 || strcmp(argv[1], "v") == 0) {
      executeVolume(tab, atoi(argv[2]));
      cmdFound = 1;
    }
  }

  if (!cmdFound) {
    usage(argv[0]);
    return 1;
  }

  return 0;
}
