#import "XXRootViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CoreMedia/CoreMedia.h>

@interface XXRootViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UISegmentedControl *modeControl;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, strong) NSMutableArray *localTracks;
@property (nonatomic, strong) NSString *serverIP;

@property (nonatomic, strong) UIView *playerView;
@property (nonatomic, strong) UILabel *nowPlayingLabel;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *downloadButton;
@property (nonatomic, strong) UIButton *deleteButton; // НОВАЯ КНОПКА
@property (nonatomic, strong) UILabel *elapsedTimeLabel;
@property (nonatomic, strong) UILabel *remainingTimeLabel;

@property (nonatomic, strong) id timeObserver;
@property (nonatomic, assign) BOOL isSeeking;
@property (nonatomic, strong) NSDictionary *currentTrackMetadata;
@end

@implementation XXRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"bg.png"]];
    self.serverIP = @"192.168.X.X:8080"; 
    
    [self loadLocalTracks];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search in network...";
    self.searchBar.tintColor = [UIColor colorWithRed:0.20 green:0.15 blue:0.10 alpha:1.0];
    [self.view addSubview:self.searchBar];

    self.modeControl = [[UISegmentedControl alloc] initWithItems:@[@"Search", @"Library"]];
    self.modeControl.frame = CGRectMake(10, 50, self.view.bounds.size.width - 20, 30);
    self.modeControl.selectedSegmentIndex = 0;
    self.modeControl.tintColor = [UIColor colorWithRed:0.40 green:0.35 blue:0.30 alpha:1.0];
    [self.modeControl addTarget:self action:@selector(modeChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.modeControl];

    CGFloat playerHeight = 100;
    CGFloat tableY = 90;
    CGFloat tableHeight = self.view.bounds.size.height - tableY - playerHeight;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, tableY, self.view.bounds.size.width, tableHeight) style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [UIColor colorWithRed:0.25 green:0.20 blue:0.15 alpha:0.8];
    [self.view addSubview:self.tableView];

    [self setupPlayerUIWithHeight:playerHeight];
}

- (BOOL)canBecomeFirstResponder { return YES; }

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent {
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        if (receivedEvent.subtype == UIEventSubtypeRemoteControlPlay || 
            receivedEvent.subtype == UIEventSubtypeRemoteControlPause || 
            receivedEvent.subtype == UIEventSubtypeRemoteControlTogglePlayPause) {
            [self playPauseTapped];
        }
    }
}

- (void)setupPlayerUIWithHeight:(CGFloat)height {
    CGFloat yPos = self.view.bounds.size.height - height;
    self.playerView = [[UIView alloc] initWithFrame:CGRectMake(0, yPos, self.view.bounds.size.width, height)];
    self.playerView.backgroundColor = [UIColor colorWithRed:0.10 green:0.08 blue:0.06 alpha:0.98];
    
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 1)];
    line.backgroundColor = [UIColor colorWithRed:0.7 green:0.6 blue:0.4 alpha:0.4];
    [self.playerView addSubview:line];

    self.nowPlayingLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, self.view.bounds.size.width - 65, 22)];
    self.nowPlayingLabel.textColor = [UIColor colorWithRed:0.93 green:0.89 blue:0.82 alpha:1.0];
    self.nowPlayingLabel.font = [UIFont fontWithName:@"Baskerville-Italic" size:17.0];
    self.nowPlayingLabel.backgroundColor = [UIColor clearColor]; 
    self.nowPlayingLabel.text = @"Waiting...";
    [self.playerView addSubview:self.nowPlayingLabel];

    self.downloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.downloadButton.frame = CGRectMake(self.view.bounds.size.width - 45, 8, 40, 30);
    [self.downloadButton setTitle:@"⬇" forState:UIControlStateNormal];
    [self.downloadButton setTitleColor:[UIColor colorWithRed:0.7 green:0.6 blue:0.4 alpha:1.0] forState:UIControlStateNormal];
    [self.downloadButton addTarget:self action:@selector(downloadCurrentTrack) forControlEvents:UIControlEventTouchUpInside];
    [self.playerView addSubview:self.downloadButton];

    self.deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.deleteButton.frame = CGRectMake(self.view.bounds.size.width - 45, 8, 40, 30);
    [self.deleteButton setTitle:@"✖" forState:UIControlStateNormal];
    [self.deleteButton setTitleColor:[UIColor colorWithRed:0.6 green:0.2 blue:0.2 alpha:1.0] forState:UIControlStateNormal];
    [self.deleteButton addTarget:self action:@selector(deleteCurrentTrack) forControlEvents:UIControlEventTouchUpInside];
    self.deleteButton.hidden = YES; 
    [self.playerView addSubview:self.deleteButton];

    self.elapsedTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 40, 45, 20)];
    self.elapsedTimeLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:12];
    self.elapsedTimeLabel.textColor = [UIColor colorWithRed:0.8 green:0.7 blue:0.6 alpha:1.0];
    self.elapsedTimeLabel.backgroundColor = [UIColor clearColor]; 
    self.elapsedTimeLabel.text = @"0:00";
    [self.playerView addSubview:self.elapsedTimeLabel];

    self.progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(55, 40, self.view.bounds.size.width - 110, 20)];
    self.progressSlider.minimumTrackTintColor = [UIColor colorWithRed:0.6 green:0.5 blue:0.4 alpha:1.0];
    [self.progressSlider addTarget:self action:@selector(sliderTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.progressSlider addTarget:self action:@selector(sliderTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.playerView addSubview:self.progressSlider];

    self.remainingTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 50, 40, 45, 20)];
    self.remainingTimeLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:12];
    self.remainingTimeLabel.textColor = [UIColor colorWithRed:0.8 green:0.7 blue:0.6 alpha:1.0];
    self.remainingTimeLabel.backgroundColor = [UIColor clearColor]; 
    self.remainingTimeLabel.text = @"0:00";
    [self.playerView addSubview:self.remainingTimeLabel];

    self.playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playPauseButton.frame = CGRectMake(self.view.bounds.size.width / 2 - 25, 65, 50, 30);
    [self.playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
    [self.playPauseButton addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.playerView addSubview:self.playPauseButton];

    [self.view addSubview:self.playerView];
}


- (void)deleteCurrentTrack {
    if (!self.currentTrackMetadata || !self.currentTrackMetadata[@"localPath"]) return;

    NSString *fileName = self.currentTrackMetadata[@"localPath"];
    NSString *filePath = [[self downloadsPath] stringByAppendingPathComponent:fileName];

    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];

    NSDictionary *trackToRemove = nil;
    for (NSDictionary *t in self.localTracks) {
        if ([t[@"id"] isEqualToString:self.currentTrackMetadata[@"id"]]) {
            trackToRemove = t;
            break;
        }
    }

    if (trackToRemove) {
        [self.localTracks removeObject:trackToRemove];
        [self saveLocalTracks];
        [self.tableView reloadData];
    }

    [self.player pause];
    self.nowPlayingLabel.text = @"Track deleted";
    self.deleteButton.hidden = YES;
    self.currentTrackMetadata = nil;
    self.progressSlider.value = 0;
    self.elapsedTimeLabel.text = @"0:00";
    self.remainingTimeLabel.text = @"0:00";
    [self.playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
}

- (void)downloadCurrentTrack {
    if (!self.currentTrackMetadata) return;
    NSDictionary *track = self.currentTrackMetadata;
    [self.downloadButton setTitle:@"..." forState:UIControlStateNormal];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *encodedId = [track[@"id"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *urlStr = [NSString stringWithFormat:@"http://%@/track?id=%@", self.serverIP, encodedId];
        NSData *jsonData = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlStr]];
        if (jsonData) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            NSData *audioData = [NSData dataWithContentsOfURL:[NSURL URLWithString:json[@"stream_url"]]];
            if (audioData) {
                NSString *safeId = [track[@"id"] stringByReplacingOccurrencesOfString:@" " withString:@"_"];
                
                // ВАЖНО: сохраняем как MP4!
                NSString *fileName = [NSString stringWithFormat:@"%@.mp4", safeId];
                NSString *path = [[self downloadsPath] stringByAppendingPathComponent:fileName];
                [audioData writeToFile:path atomically:YES];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSMutableDictionary *local = [track mutableCopy];
                    [local setObject:fileName forKey:@"localPath"];
                    [self.localTracks addObject:local];
                    [self saveLocalTracks];
            
                    self.currentTrackMetadata = local;
                    self.downloadButton.hidden = YES;
                    self.deleteButton.hidden = NO;
                    [self.tableView reloadData];
                });
            }
        }
    });
}


- (void)playURL:(NSURL *)url title:(NSString *)title artist:(NSString *)artist {
    if (self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }

    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    [item addObserver:self forKeyPath:@"status" options:0 context:nil];
    self.player = [AVPlayer playerWithPlayerItem:item];
    
    self.nowPlayingLabel.text = title;

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setObject:title forKey:MPMediaItemPropertyTitle];
    [info setObject:artist forKey:MPMediaItemPropertyArtist];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:info];

    __weak typeof(self) weakSelf = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        double current = CMTimeGetSeconds(time);
        double total = CMTimeGetSeconds(weakSelf.player.currentItem.duration);
        
        if (total > 0 && !isnan(total) && total < 10800) { 
            weakSelf.progressSlider.maximumValue = total;
            weakSelf.progressSlider.value = current;
            weakSelf.elapsedTimeLabel.text = [NSString stringWithFormat:@"%d:%02d", (int)current/60, (int)current%60];
            weakSelf.remainingTimeLabel.text = [NSString stringWithFormat:@"%d:%02d", (int)total/60, (int)total%60];
            
            NSMutableDictionary *nowPlaying = [NSMutableDictionary dictionaryWithDictionary:[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo]];
            [nowPlaying setObject:[NSNumber numberWithDouble:total] forKey:MPMediaItemPropertyPlaybackDuration];
            [nowPlaying setObject:[NSNumber numberWithDouble:current] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
            [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nowPlaying];
        }
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *track = (self.modeControl.selectedSegmentIndex == 0) ? self.searchResults[indexPath.row] : self.localTracks[indexPath.row];
    self.currentTrackMetadata = track;

    if (track[@"localPath"]) {
        self.downloadButton.hidden = YES;
        self.deleteButton.hidden = NO;
        
        NSString *path = [[self downloadsPath] stringByAppendingPathComponent:track[@"localPath"]];
        [self playURL:[NSURL fileURLWithPath:path] title:track[@"title"] artist:track[@"artist"]];
    } else {
        self.downloadButton.hidden = NO;
        self.deleteButton.hidden = YES;
        [self.downloadButton setTitle:@"⬇" forState:UIControlStateNormal];
        
        self.nowPlayingLabel.text = @"Загрузка...";
        NSString *encodedId = [track[@"id"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSURL *u = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/track?id=%@", self.serverIP, encodedId]];
        [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:u] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
            if (d) {
                NSDictionary *j = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
                [self playURL:[NSURL URLWithString:j[@"stream_url"]] title:track[@"title"] artist:track[@"artist"]];
            }
        }];
    }
}

- (NSString *)downloadsPath { return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]; }
- (void)loadLocalTracks { NSString *p = [[self downloadsPath] stringByAppendingPathComponent:@"library.plist"]; self.localTracks = [NSMutableArray arrayWithContentsOfFile:p] ?: [NSMutableArray array]; }
- (void)saveLocalTracks { NSString *p = [[self downloadsPath] stringByAppendingPathComponent:@"library.plist"]; [self.localTracks writeToFile:p atomically:YES]; }

- (void)modeChanged { [self.tableView reloadData]; self.searchBar.hidden = (self.modeControl.selectedSegmentIndex == 1); }
- (void)playPauseTapped { 
    if (self.player.rate > 0) { [self.player pause]; [self.playPauseButton setTitle:@"▶" forState:UIControlStateNormal]; }
    else { [self.player play]; [self.playPauseButton setTitle:@"❚❚" forState:UIControlStateNormal]; }
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"] && self.player.status == AVPlayerStatusReadyToPlay) { [self.player play]; [self.playPauseButton setTitle:@"❚❚" forState:UIControlStateNormal]; }
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)sb {
    [sb resignFirstResponder];
    NSString *q = [sb.text stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *u = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/search?q=%@", self.serverIP, q]];
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:u] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
        if (d) { self.searchResults = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil]; [self.tableView reloadData]; }
    }];
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return (self.modeControl.selectedSegmentIndex == 0) ? self.searchResults.count : self.localTracks.count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"C"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"C"];
    NSDictionary *t = (self.modeControl.selectedSegmentIndex == 0) ? self.searchResults[ip.row] : self.localTracks[ip.row];
    c.textLabel.text = t[@"title"]; c.detailTextLabel.text = t[@"artist"];
    c.backgroundColor = [UIColor clearColor]; c.textLabel.textColor = [UIColor whiteColor];
    return c;
}
- (void)sliderTouchDown { self.isSeeking = YES; }
- (void)sliderTouchUp { self.isSeeking = NO; [self.player seekToTime:CMTimeMakeWithSeconds(self.progressSlider.value, 1000)]; }

@end
