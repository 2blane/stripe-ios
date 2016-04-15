//
//  STPInitialPaymentDetailsCoordinatorTests.m
//  Stripe iOS Example (Simple)
//
//  Created by Ben Guo on 3/29/16.
//  Copyright © 2016 Stripe. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Stripe/Stripe.h>
#import "MockSTPAPIClient.h"
#import "MockSTPBackendAPIAdapter.h"
#import "MockSTPCoordinatorDelegate.h"
#import "MockUINavigationController.h"
#import "STPPaymentCardEntryViewController.h"
#import "STPInitialLoadingViewController.h"
#import "STPShippingEntryViewController.h"
#import "STPInitialPaymentDetailsCoordinator.h"

@interface STPShippingEntryViewController();
@property (nonatomic, assign) PKAddressField requiredAddressFields;
@end

@interface STPInitialPaymentDetailsCoordinator()<STPPaymentCardEntryViewControllerDelegate, STPShippingEntryViewControllerDelegate>
@property(nonatomic, readonly)UINavigationController *navigationController;
@end

@interface STPInitialPaymentDetailsCoordinatorTests : XCTestCase

@property (nonatomic, strong) STPInitialPaymentDetailsCoordinator *sut;
@property (nonatomic, strong) MockUINavigationController *navigationController;
@property (nonatomic, strong) MockSTPAPIClient *apiClient;
@property (nonatomic, strong) MockSTPBackendAPIAdapter *apiAdapter;
@property (nonatomic, strong) MockSTPCoordinatorDelegate *delegate;
@property (nonatomic, strong) STPCardParams *card;
@property (nonatomic, strong) PKPaymentRequest *paymentRequest;

@end

@implementation STPInitialPaymentDetailsCoordinatorTests

- (void)setUp {
    [super setUp];
    self.navigationController = [MockUINavigationController new];
    self.apiClient = [MockSTPAPIClient new];
    self.apiAdapter = [MockSTPBackendAPIAdapter new];
    self.delegate = [MockSTPCoordinatorDelegate new];
    self.paymentRequest = [[PKPaymentRequest alloc] init];
    self.sut = [[STPInitialPaymentDetailsCoordinator alloc] initWithNavigationController:self.navigationController
                                                                          paymentRequest:self.paymentRequest
                                                                               apiClient:self.apiClient
                                                                          apiAdapter:self.apiAdapter
                                                                                delegate:self.delegate];
    STPCardParams *card = [[STPCardParams alloc] init];
    card.number = @"4242 4242 4242 4242";
    card.expMonth = 6;
    card.expYear = 2018;
    card.currency = @"usd";
    self.card = card;
}

- (void)tearDown {
    [super tearDown];
    self.navigationController = nil;
    self.apiClient = nil;
    self.apiAdapter = nil;
    self.delegate = nil;
    self.paymentRequest = nil;
    self.sut = nil;
    self.card = nil;
}

- (void)testBegin_noSelectedSource_showsCardVC {
    self.apiAdapter.selectedSource = nil;
    [self.sut begin];
    UIViewController *topVC = self.sut.navigationController.topViewController;
    XCTAssertTrue([topVC isKindOfClass:[STPPaymentCardEntryViewController class]]);
}

- (void)testBegin_selectedSource_requiredAddressFields_showsShippingVC {
    self.apiAdapter.selectedSource = [STPToken new];
    self.paymentRequest.requiredShippingAddressFields = PKAddressFieldAll;
    [self.sut begin];
    UIViewController *topVC = self.sut.navigationController.topViewController;
    XCTAssertTrue([topVC isKindOfClass:[STPShippingEntryViewController class]]);
}

- (void)testBegin_selectedSource_noRequiredAddressFields_completes {
    self.apiAdapter.selectedSource = [STPToken new];
    self.paymentRequest.requiredShippingAddressFields = PKAddressFieldNone;
    XCTestExpectation *exp = [self expectationWithDescription:@"cancel"];
    self.delegate.onWillFinishWithCompletion = ^(__unused STPErrorBlock completion){ [exp fulfill]; };

    [self.sut begin];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testBegin_retrieveSourcesError {
    self.apiAdapter.retrieveSourcesError = [NSError new];

    [self.sut begin];
    UIViewController *topVC = self.sut.navigationController.topViewController;
    XCTAssertTrue([topVC isKindOfClass:[STPInitialLoadingViewController class]]);
}

- (void)testCancelCardEntry {
    XCTestExpectation *exp = [self expectationWithDescription:@"cancel"];
    self.delegate.onDidCancel = ^(){ [exp fulfill]; };

    [self.sut begin];
    [self.sut paymentCardEntryViewControllerDidCancel:nil];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testEnterCard_success_pushesShippingVC_withRequiredAddressFields {
    XCTestExpectation *pushExp = [self expectationWithDescription:@"finish"];
    XCTestExpectation *completionExp = [self expectationWithDescription:@"completion"];
    self.paymentRequest.requiredShippingAddressFields = PKAddressFieldAll;
    __weak typeof(self) weakSelf = self;
    self.navigationController.onPushViewController = ^(UIViewController *vc, __unused BOOL animated) {
        _XCTPrimitiveAssertTrue(weakSelf, [vc isKindOfClass:[STPShippingEntryViewController class]], @"");
        STPShippingEntryViewController *shippingVC = (STPShippingEntryViewController *)vc;
        _XCTPrimitiveAssertTrue(weakSelf, shippingVC.requiredAddressFields == PKAddressFieldAll, @"");
        [pushExp fulfill];
    };

    [self.sut begin];
    [self.sut paymentCardEntryViewController:nil didEnterCardParams:self.card completion:^(__unused NSError * _Nullable paramsError) {
        [completionExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testEnterCard_success_completes_withNoRequiredAddressFields {
    XCTestExpectation *finishExp = [self expectationWithDescription:@"willFinish"];
    XCTestExpectation *completionExp = [self expectationWithDescription:@"completion"];
    self.paymentRequest.requiredShippingAddressFields = PKAddressFieldNone;
    __weak typeof(self) weakSelf = self;
    self.delegate.onWillFinishWithCompletion = ^(STPErrorBlock completion) {
        completion(nil);
        [finishExp fulfill];
    };
    self.navigationController.onPushViewController = ^(__unused UIViewController *vc, __unused BOOL animated) {
        _XCTPrimitiveFail(weakSelf, "should not be called");
    };

    [self.sut begin];
    [self.sut paymentCardEntryViewController:nil didEnterCardParams:self.card completion:^(__unused NSError * _Nullable paramsError) {
        [completionExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testEnterCard_apiClientError {
    NSError *expectedError = [NSError new];
    self.apiClient.error = expectedError;
    __weak id weakSelf = self;
    self.delegate.onWillFinishWithCompletion = ^(__unused STPErrorBlock completion) {
        _XCTPrimitiveFail(weakSelf, "should not be called");
    };

    XCTestExpectation *exp = [self expectationWithDescription:@"completion"];
    [self.sut begin];
    [self.sut paymentCardEntryViewController:nil didEnterCardParams:self.card completion:^(NSError * error) {
        _XCTPrimitiveAssertEqualObjects(weakSelf, expectedError, @"", error, @"");
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testEnterCard_apiAdapterError {
    NSError *expectedError = [[NSError alloc] initWithDomain:@"foo" code:123 userInfo:@{}];
    self.apiAdapter.addSourceError = expectedError;
    __weak id weakSelf = self;
    self.delegate.onWillFinishWithCompletion = ^(__unused STPErrorBlock completion) {
        _XCTPrimitiveFail(weakSelf, "should not be called");
    };

    XCTestExpectation *exp = [self expectationWithDescription:@"completion"];
    [self.sut begin];
    [self.sut paymentCardEntryViewController:nil didEnterCardParams:self.card completion:^(NSError * _Nullable error) {
        XCTAssertEqualObjects(error, expectedError);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testEnterCard_enterShipping {
    XCTestExpectation *pushExp = [self expectationWithDescription:@"push"];
    XCTestExpectation *completionExp = [self expectationWithDescription:@"completion"];
    XCTestExpectation *willFinishExp = [self expectationWithDescription:@"willFinish"];
    self.paymentRequest.requiredShippingAddressFields = PKAddressFieldAll;
    __weak typeof(self) weakSelf = self;
    self.navigationController.onPushViewController = ^(UIViewController *vc, __unused BOOL animated) {
        _XCTPrimitiveAssertTrue(weakSelf, [vc isKindOfClass:[STPShippingEntryViewController class]], @"");
        STPShippingEntryViewController *shippingVC = (STPShippingEntryViewController *)vc;
        [weakSelf.sut shippingEntryViewController:shippingVC didEnterShippingAddress:[STPAddress new] completion:^(NSError *error) {
            _XCTPrimitiveAssertNil(weakSelf, error, @"");
            [completionExp fulfill];
        }];
        [pushExp fulfill];
    };
    self.delegate.onWillFinishWithCompletion = ^(STPErrorBlock completion) {
        completion(nil);
        [willFinishExp fulfill];
    };

    [self.sut begin];
    [self.sut paymentCardEntryViewController:nil didEnterCardParams:self.card completion:nil];
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testEnterCard_cancelShipping_tellsDelegate {
    XCTestExpectation *pushExp = [self expectationWithDescription:@"push"];
    XCTestExpectation *cancelExp = [self expectationWithDescription:@"cancel"];
    self.paymentRequest.requiredShippingAddressFields = PKAddressFieldAll;
    __weak typeof(self) weakSelf = self;
    self.navigationController.onPushViewController = ^(UIViewController *vc, __unused BOOL animated) {
        _XCTPrimitiveAssertTrue(weakSelf, [vc isKindOfClass:[STPShippingEntryViewController class]], @"");
        STPShippingEntryViewController *shippingVC = (STPShippingEntryViewController *)vc;
        [weakSelf.sut shippingEntryViewControllerDidCancel:shippingVC];
        [pushExp fulfill];
    };
    self.navigationController.onPopViewController = ^(__unused BOOL animated) {
        _XCTPrimitiveFail(weakSelf, @"should not be called");
    };
    self.delegate.onDidCancel = ^() {
        [cancelExp fulfill];
    };
    self.delegate.onWillFinishWithCompletion = ^(__unused STPErrorBlock completion) {
        _XCTPrimitiveFail(weakSelf, @"should not be called");
    };

    [self.sut begin];
    [self.sut paymentCardEntryViewController:nil didEnterCardParams:self.card completion:nil];
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testEnterShipping_error {
    self.apiAdapter.selectedSource = [STPToken new];
    self.paymentRequest.requiredShippingAddressFields = PKAddressFieldAll;
    XCTestExpectation *completionExp = [self expectationWithDescription:@"completion"];
    __weak typeof(self) weakSelf = self;
    self.navigationController.onPopViewController = ^(__unused BOOL animated) {
        _XCTPrimitiveFail(weakSelf, @"should not be called");
    };
    self.delegate.onDidCancel = ^() {
        _XCTPrimitiveFail(weakSelf, @"should not be called");
    };
    self.delegate.onWillFinishWithCompletion = ^(__unused STPErrorBlock completion) {
        _XCTPrimitiveFail(weakSelf, @"should not be called");
    };
    NSError *expectedError = [NSError new];
    self.apiAdapter.updateCustomerShippingError = expectedError;

    [self.sut begin];
    STPShippingEntryViewController *shippingVC = (STPShippingEntryViewController *)self.sut.navigationController.topViewController;
    [self.sut shippingEntryViewController:shippingVC
                  didEnterShippingAddress:[STPAddress new]
                               completion:^(NSError *error) {
                                   XCTAssertEqual(error, expectedError);
                                   [completionExp fulfill];
                               }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

@end
