//
//  SXDetailPage.m
//  81 - 网易新闻
//
//  Created by 董 尚先 on 15-1-24.
//  Copyright (c) 2015年 ShangxianDante. All rights reserved.
//

#import "SXNewsDetailBottomCell.h"
#import "SXNewsDetailViewModel.h"
#import "SXDetailPage.h"
#import "SXSearchPage.h"
#import "SXReplyPage.h"

#define kNewsDetailControllerClose (self.tableView.contentOffset.y - (self.tableView.contentSize.height - SXSCREEN_H + 55) > (100 - 54))

@interface SXDetailPage ()<UIWebViewDelegate,UITableViewDataSource,UITableViewDelegate>
@property (strong, nonatomic) UIWebView *webView;

@property (weak, nonatomic) IBOutlet UIButton *replyCountBtn;
@property (weak, nonatomic) IBOutlet UIButton *backBtn;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property(nonatomic,strong)SXNewsDetailBottomCell *closeCell;
@property(nonatomic,strong)SXNewsDetailViewModel *viewModel;
@property(nonatomic,strong) NSArray *news;

@end

@implementation SXDetailPage

#pragma mark - **************** lazy
- (NSArray *)news
{
    if (_news == nil) {
        _news = [NSArray array];
        _news = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"NewsURLs.plist" ofType:nil]];
    }
    return _news;
}

- (UIWebView *)webView
{
    if (!_webView) {
        UIWebView *web = [[UIWebView alloc]initWithFrame:CGRectMake(0, 0, SXSCREEN_W, 700)];
        _webView = web;
    }
    return _webView;
}

- (SXNewsDetailViewModel *)viewModel
{
    if (!_viewModel) {
        _viewModel = [[SXNewsDetailViewModel alloc]init];
    }
    return _viewModel;
}

#pragma mark - ******************** lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    self.webView.delegate = self;
    
    @weakify(self)
    RAC(self.viewModel,newsModel) = RACObserve(self, newsModel);
    [[RACObserve(self.viewModel, replyCountBtnTitle)skip:1]subscribeNext:^(NSString *x) {
        @strongify(self)
        [self.replyCountBtn setTitle:x forState:UIControlStateNormal];
    }];
    
    [[self.viewModel.fetchNewsDetailCommand execute:nil]subscribeError:^(NSError *error) {
        // 暂时不做什么操作
    } completed:^{
        [self showInWebView];
        [self requestForFeedbackList];
    }];
    
    [[[RACSignal combineLatest:@[[_viewModel.fetchFeedbackCommand.executing skip:1],[_viewModel.fetchNewsDetailCommand.executing skip:1]]] filter:^BOOL(RACTuple *x) {
        return ![x.first boolValue]&&![x.second boolValue];
    }]subscribeNext:^(id x) {
        @strongify(self)
        [self.tableView reloadData];
    }];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    self.tabBarController.tabBar.hidden = YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    SXReplyPage *replyvc = segue.destinationViewController;
    replyvc.replys = self.viewModel.replyModels;
    
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.delegate = nil;
    }
    
    [[NSNotificationCenter defaultCenter]postNotification:[NSNotification notificationWithName:@"contentStart" object:nil]];
}

- (IBAction)backBtn:(id)sender {
    CFRelease((__bridge CFTypeRef)self);
    CFIndex rc = CFGetRetainCount((__bridge CFTypeRef)self);
    NSLog(@"%ld",rc);
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)dealloc
{
    NSLog(@"%s",__func__);
}

#pragma mark - ******************** webView + html
- (void)showInWebView
{
    [self.webView loadHTMLString:[self.viewModel getHtmlString] baseURL:nil];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSString *url = request.URL.absoluteString;
    NSRange range = [url rangeOfString:@"sx:src="];
    if (range.location != NSNotFound) {
        NSInteger begin = range.location + range.length;
        NSString *src = [url substringFromIndex:begin];
        [self savePictureToAlbum:src];
        return NO;
    }
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    self.webView.height = self.webView.scrollView.contentSize.height;
    [self.tableView reloadData];
}

#pragma mark - **************** tableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return self.webView;
    }else if (section == 1){
        SXNewsDetailBottomCell *head = [SXNewsDetailBottomCell theSectionHeaderCell];
        head.sectionHeaderLbl.text = @"热门跟帖";
        return head;
    }else if (section == 2){
        SXNewsDetailBottomCell *head = [SXNewsDetailBottomCell theSectionHeaderCell];
        head.sectionHeaderLbl.text = @"相关新闻";
        return head;
    }
    return [UIView new];
}

- (CGFloat )tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return self.webView.height;
    }else if (section == 1){
        return self.viewModel.replyModels.count > 0 ? 40 : CGFLOAT_MIN;
    }else if (section == 2){
        return self.viewModel.sameNews.count > 0 ? 40 : CGFLOAT_MIN;
    }
    return CGFLOAT_MIN;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section == 2){
        SXNewsDetailBottomCell *closeCell = [SXNewsDetailBottomCell theCloseCell];
        self.closeCell = closeCell;
        return closeCell;
    }
    return [[UIView alloc]init];
}

- (CGFloat )tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == 2){
        return 64;
    }
    return 15;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 1;
    }else if (section == 1){
        return 1 + self.viewModel.replyModels.count;
    }else if (section == 2){
        return self.viewModel.sameNews.count;
    }
    return 0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1) {
        if (indexPath.row == self.viewModel.replyModels.count) {
            [self performSegueWithIdentifier:@"toReply" sender:nil];
        }
    }else if (indexPath.section == 2){
        if (indexPath.row > 0) {
            SXNewsEntity *model = [[SXNewsEntity alloc]init];
            model.docid = [self.viewModel.sameNews[indexPath.row] id];
            
            UIStoryboard *sb = [UIStoryboard storyboardWithName:@"News" bundle:nil];
            SXDetailPage *devc = (SXDetailPage *)[sb instantiateViewControllerWithIdentifier:@"SXDetailPage"];
            devc.newsModel = model;
            [self.navigationController pushViewController:devc animated:YES];
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        return [SXNewsDetailBottomCell theShareCell];
    }else if (indexPath.section == 1){
        if (indexPath.row == self.viewModel.replyModels.count) {
            SXNewsDetailBottomCell *foot = [SXNewsDetailBottomCell theSectionBottomCell];
            return foot;
        }else{
            SXNewsDetailBottomCell *hotreply = [SXNewsDetailBottomCell theHotReplyCellWithTableView:tableView];
            hotreply.replyModel = self.viewModel.replyModels[indexPath.row];
            return hotreply;
        }
    }else if (indexPath.section == 2){
        if (indexPath.row == 0) {
            SXNewsDetailBottomCell *cell = [SXNewsDetailBottomCell theKeywordCell];
            [cell.contentView addSubview:[self addKeywordButton]];
            return cell;
        }else{
            SXNewsDetailBottomCell *other = [SXNewsDetailBottomCell theContactNewsCell];
            other.sameNewsEntity = self.viewModel.sameNews[indexPath.row];
            return other;
        }
    }
    return [UITableViewCell new];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        return 126;
    }else if (indexPath.section == 1){
        if (indexPath.row == self.viewModel.replyModels.count) {
            return 50;
        }else{
            return 110.5;
        }
    }else if (indexPath.section == 2){
        if (indexPath.row == 0) {
            return 60;
        }else{
            return 81;
        }
    }
    return CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        return 126;
    }else if (indexPath.section == 1){
        if (indexPath.row == self.viewModel.replyModels.count) {
            return 50;
        }else{
            return 110.5;
        }
    }else if (indexPath.section == 2){
        if (indexPath.row == 0) {
            return 60;
        }else{
            return 81;
        }
    }
    return CGFLOAT_MIN;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (self.closeCell) {
        self.closeCell.iSCloseing = kNewsDetailControllerClose;
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (kNewsDetailControllerClose) {
        UIImageView *imgV =[[UIImageView alloc]initWithFrame:CGRectMake(0, 0, SXSCREEN_W, SXSCREEN_H)];
        imgV.image = [self getImage];
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        [window addSubview:imgV];
        [self.navigationController popViewControllerAnimated:NO];
        imgV.alpha = 1.0;
        [UIView animateWithDuration:0.3 animations:^{
            imgV.frame = CGRectMake(0, SXSCREEN_H/2, SXSCREEN_W, 0);
            imgV.alpha = 0.0;
        } completion:^(BOOL finished) {
            [imgV removeFromSuperview];
        }];
    }
}

#pragma mark - **************** other
// 提前把评论的请求也发出去 得到评论的信息
- (void)requestForFeedbackList
{
    [self.viewModel.fetchFeedbackCommand execute:nil];
    // 成功和失败暂时都不做什么操作，所以subscribe就不写了
}

- (UIView *)addKeywordButton
{
    CGFloat maxRight = 20;
    UIView *view = [[UIView alloc]initWithFrame:CGRectMake(0, 0, SXSCREEN_W, 60)];
    for (int i = 0;i<self.viewModel.keywordSearch.count ; ++i) {
        UIButton *button = [[UIButton alloc]initWithFrame:CGRectMake(maxRight, 10, 0, 0)];
        button.titleLabel.font = [UIFont systemFontOfSize:14];
        [button setTitleColor:SXRGBColor(74, 133, 198) forState:UIControlStateNormal];
        [button setTitle:self.viewModel.keywordSearch[i][@"word"] forState:UIControlStateNormal];
        [button setBackgroundImage:[UIImage imageNamed:@"choose_city_normal"] forState:UIControlStateNormal];
        [button setBackgroundImage:[UIImage imageNamed:@"choose_city_highlight"] forState:UIControlStateHighlighted];
        [button sizeToFit];
        button.width += 20;
        button.height = 35;
        
        [self rac_liftSelector:@selector(keywordButtonClick:) withSignalsFromArray:@[[button rac_signalForControlEvents:UIControlEventTouchUpInside]]];
 
        maxRight = button.x + button.width + 10;
        [view addSubview:button];
    }
    return view;
}

- (void)keywordButtonClick:(UIButton *)sender
{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    SXSearchPage *sp = [sb instantiateViewControllerWithIdentifier:@"SXSearchPage"];
    sp.keyword = sender.titleLabel.text;
    [self.navigationController pushViewController:sp animated:YES];
}

// 截图用于做上划返回
- (UIImage *)getImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(SXSCREEN_W, SXSCREEN_H), NO, 1.0);
    [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// 将图片保存到相册
- (void)savePictureToAlbum:(NSString *)src
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"确定要保存到相册吗？" preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        
        NSURLCache *cache =[NSURLCache sharedURLCache];
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:src]];
        NSData *imgData = [cache cachedResponseForRequest:request].data;
        UIImage *image = [UIImage imageWithData:imgData];
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    }]];
    
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
