//  Created by Monte Hurd on 2/10/14.
//  Copyright (c) 2013 Wikimedia Foundation. Provided under MIT-style license; please copy and modify!

#import "WikipediaAppUtils.h"
#import "LoginViewController.h"
#import "CenterNavController.h"
#import "QueuesSingleton.h"
#import "LoginTokenOp.h"
#import "LoginOp.h"
#import "SessionSingleton.h"
#import "UIViewController+Alert.h"
#import "NSHTTPCookieStorage+CloneCookie.h"
#import "AccountCreationViewController.h"
#import "WMF_Colors.h"
#import "MenuButton.h"
#import "PaddedLabel.h"
#import "RootViewController.h"
#import "TopMenuViewController.h"
#import "CreateAccountFunnel.h"
#import "PreviewAndSaveViewController.h"
#import "SectionEditorViewController.h"
#import "OnboardingViewController.h"
#import "WebViewController.h"
#import "UIViewController+ModalPresent.h"
#import "AccountCreationViewController.h"
#import "UIViewController+ModalsSearch.h"
#import "UIViewController+ModalPop.h"

@interface LoginViewController (){

}

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UITextField *usernameField;
@property (weak, nonatomic) IBOutlet UITextField *passwordField;
@property (weak, nonatomic) IBOutlet PaddedLabel *createAccountButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *usernameUnderlineHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *passwordUnderlineHeight;
@property (weak, nonatomic) IBOutlet PaddedLabel *titleLabel;

@end

@implementation LoginViewController

-(NavBarMode)navBarMode
{
    return NAVBAR_MODE_LOGIN;
}

- (BOOL)prefersStatusBarHidden
{
    return NAV.isEditorOnNavstack;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    self.navigationItem.hidesBackButton = YES;

    self.createAccountButton.textColor = WMF_COLOR_BLUE;
    self.createAccountButton.padding = UIEdgeInsetsMake(10, 10, 10, 10);
    self.createAccountButton.text = MWLocalizedString(@"login-account-creation", nil);
    self.createAccountButton.userInteractionEnabled = YES;
    [self.createAccountButton addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(createAccountButtonPushed:)]];

    self.usernameField.attributedPlaceholder =
        [self getAttributedPlaceholderForString:MWLocalizedString(@"login-username-placeholder-text", nil)];
    self.passwordField.attributedPlaceholder =
        [self getAttributedPlaceholderForString:MWLocalizedString(@"login-password-placeholder-text", nil)];

    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress)];
    longPressRecognizer.minimumPressDuration = 1.0f;
    [self.view addGestureRecognizer:longPressRecognizer];

    if ([self.scrollView respondsToSelector:@selector(keyboardDismissMode)]) {
        self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    }
    
    [self.usernameField addTarget: self
                           action: @selector(textFieldDidChange:)
                 forControlEvents: UIControlEventEditingChanged];
    
    [self.passwordField addTarget: self
                           action: @selector(textFieldDidChange:)
                 forControlEvents: UIControlEventEditingChanged];

    self.usernameUnderlineHeight.constant = 1.0f / [UIScreen mainScreen].scale;
    self.passwordUnderlineHeight.constant = self.usernameUnderlineHeight.constant;

    // Hide the account creation button if the AccountCreationViewController is on modal stack.
    self.createAccountButton.hidden = [self searchModalsForViewControllerOfClass:[AccountCreationViewController class]] ? YES : NO;

    /*
    PreviewAndSaveViewController *previewAndSaveVC = [self searchModalsForViewControllerOfClass:[PreviewAndSaveViewController class]];
    self.titleLabel.text = (!previewAndSaveVC) ?
        MWLocalizedString(@"navbar-title-mode-login", nil)
        :
        MWLocalizedString(@"navbar-title-mode-login-and-save", nil)
    ;
    */
    self.titleLabel.text = MWLocalizedString(@"navbar-title-mode-login", nil);

    self.usernameField.textAlignment = [WikipediaAppUtils rtlSafeAlignment];
    self.passwordField.textAlignment = [WikipediaAppUtils rtlSafeAlignment];
}

-(NSAttributedString *)getAttributedPlaceholderForString:(NSString *)string
{
    return [[NSMutableAttributedString alloc] initWithString: string
                                                  attributes: @{
                                                               NSForegroundColorAttributeName : [UIColor lightGrayColor]
                                                               }];
}

-(void)textFieldDidChange:(id)sender
{
    BOOL shouldHighlight = ((self.usernameField.text.length > 0) && (self.passwordField.text.length > 0)) ? YES : NO;
    [self highlightProgressiveButton:shouldHighlight];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.usernameField) {
        [self.passwordField becomeFirstResponder];
    }else if(textField == self.passwordField) {
        [self save];
    }
    return YES;
}

-(void)highlightProgressiveButton:(BOOL)highlight
{
    MenuButton *button = (MenuButton *)[self.topMenuViewController getNavBarItem:NAVBAR_BUTTON_DONE];
    button.enabled = highlight;
}

// Handle nav bar taps.
- (void)navItemTappedNotification:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    UIView *tappedItem = userInfo[@"tappedItem"];

    switch (tappedItem.tag) {
        case NAVBAR_BUTTON_DONE:
            [self save];
            break;
        case NAVBAR_BUTTON_X:
        case NAVBAR_BUTTON_ARROW_LEFT:
            [self popModal];
            break;
        default:
            break;
    }
}

-(void)handleLongPress
{
    // Uncomment for presentation username/pwd auto entry
    // self.usernameField.text = @"montehurd";
    // self.passwordField.text = @"";
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.topMenuViewController.navBarMode = NAVBAR_MODE_LOGIN;

    [self highlightProgressiveButton:NO];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.usernameField becomeFirstResponder];

    // Listen for nav bar taps.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(navItemTappedNotification:) name:@"NavItemTapped" object:nil];
}

-(void)save
{
    id onboardingVC = [self searchModalsForViewControllerOfClass:[OnboardingViewController class]];

    [self loginWithUserName: self.usernameField.text
                   password: self.passwordField.text
                  onSuccess: ^{
                  
                      NSString *loggedInMessage = MWLocalizedString(@"main-menu-account-title-logged-in", nil);
                      loggedInMessage = [loggedInMessage stringByReplacingOccurrencesOfString: @"$1"
                                                                                   withString: self.usernameField.text];
                      [self showAlert:loggedInMessage];
                      [self fadeAlert];

                      [self performSelector:(onboardingVC ? @selector(popModalToRoot) : @selector(popModal)) withObject:nil afterDelay:1.2f];
                      
                  } onFail: nil];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [self highlightProgressiveButton:NO];

    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"NavItemTapped" object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)loginWithUserName: (NSString *)userName
                password: (NSString *)password
               onSuccess: (void (^)(void))successBlock
                  onFail: (void (^)(void))failBlock
{
    [self fadeAlert];

    // Fix for iOS 6 crashing on empty credentials.
    if (!userName) userName = @"";
    if (!password) password = @"";

    if (!successBlock) successBlock = ^(){};
    if (!failBlock) failBlock = ^(){};

    /*
    void (^printCookies)() =  ^void(){
        NSLog(@"\n\n\n\n\n\n\n\n\n\n");
        for (NSHTTPCookie *cookie in [NSHTTPCookieStorage sharedHTTPCookieStorage].cookies) {
            NSLog(@"cookies = %@", cookie.properties);
        }
        NSLog(@"\n\n\n\n\n\n\n\n\n\n");
    };
     */
    
    //[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    
    LoginOp *loginOp =
    [[LoginOp alloc] initWithUsername: userName
                             password: password
                               domain: [SessionSingleton sharedInstance].domain
                      completionBlock: ^(NSDictionary *loginResult){
                          
                          NSLog(@"%@", loginResult);
                          NSString *loginStatus = loginResult[@"login"][@"result"];
                          
                          // Login credentials should only be placed in the keychain if they've been authenticated.
                          NSString *normalizedUserName = loginResult[@"login"][@"lgusername"];
                          [SessionSingleton sharedInstance].keychainCredentials.userName = normalizedUserName;
                          [SessionSingleton sharedInstance].keychainCredentials.password = password;
                          
                          //NSString *result = loginResult[@"login"][@"result"];
                          [self showAlert:loginStatus];
                          
                          [[NSOperationQueue mainQueue] addOperationWithBlock:successBlock];
                          
                          [self cloneSessionCookies];
                          //printCookies();

                          [self.funnel logSuccess];
                          
                      } cancelledBlock: ^(NSError *error){
                          
                          [self showAlert:error.localizedDescription];

                          [[NSOperationQueue mainQueue] addOperationWithBlock:failBlock];

                          
                      } errorBlock: ^(NSError *error){
                          
                          [self showAlert:error.localizedDescription];

                          [[NSOperationQueue mainQueue] addOperationWithBlock:failBlock];


                          [self.funnel logError:error.localizedDescription];
                      }];
    
    LoginTokenOp *loginTokenOp =
    [[LoginTokenOp alloc] initWithUsername: userName
                                  password: password
                                    domain: [SessionSingleton sharedInstance].domain
                           completionBlock: ^(NSString *tokenRetrieved){
                               
                               NSLog(@"loginTokenOp token = %@", tokenRetrieved);
                               loginOp.token = tokenRetrieved;
                           } cancelledBlock: ^(NSError *error){
                               
                               [self fadeAlert];

                               [[NSOperationQueue mainQueue] addOperationWithBlock:failBlock];
                               
                           } errorBlock: ^(NSError *error){
                               
                               [self showAlert:error.localizedDescription];

                               [[NSOperationQueue mainQueue] addOperationWithBlock:failBlock];

                               [self.funnel logError:error.localizedDescription];
                           }];
    
    loginTokenOp.delegate = self;
    loginOp.delegate = self;
    
    // The loginTokenOp needs to succeed before the loginOp can begin.
    [loginOp addDependency:loginTokenOp];
    
    [[QueuesSingleton sharedInstance].loginQ cancelAllOperations];
    [QueuesSingleton sharedInstance].loginQ.suspended = YES;
    [[QueuesSingleton sharedInstance].loginQ addOperation:loginTokenOp];
    [[QueuesSingleton sharedInstance].loginQ addOperation:loginOp];
    [QueuesSingleton sharedInstance].loginQ.suspended = NO;
}

-(void)cloneSessionCookies
{
    // Make the session cookies expire at same time user cookies. Just remember they still can't be
    // necessarily assumed to be valid as the server may expire them, but at least make them last as
    // long as we can to lessen number of server requests. Uses user tokens as templates for copying
    // session tokens. See "recreateCookie:usingCookieAsTemplate:" for details.

    NSString *domain = [SessionSingleton sharedInstance].domain;

    NSString *cookie1Name = [NSString stringWithFormat:@"%@wikiSession", domain];
    NSString *cookie2Name = [NSString stringWithFormat:@"%@wikiUserID", domain];
    
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] recreateCookie: cookie1Name
                                            usingCookieAsTemplate: cookie2Name
     ];
    
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] recreateCookie: @"centralauth_Session"
                                            usingCookieAsTemplate: @"centralauth_User"
     ];
}

- (void)createAccountButtonPushed:(id)sender
{
    [self.funnel logCreateAccountAttempt];

    [self performModalSequeWithID: @"modal_segue_show_create_account"
                  transitionStyle: UIModalTransitionStyleCoverVertical
                            block: ^(AccountCreationViewController *createAcctVC){
                                createAcctVC.funnel = [[CreateAccountFunnel alloc] init];
                                [createAcctVC.funnel logStartFromLogin:self.funnel.loginSessionToken];
                            }];
}

@end
