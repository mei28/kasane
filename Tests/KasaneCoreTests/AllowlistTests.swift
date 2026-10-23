import KasaneCore
import Testing

@Test func countsOnlyDevicesWhoseVendorAndProductIDsBothMatch() {
    let config = Config(
        externalKeyboards: [ExternalKeyboard(name: "HHKB", vendorID: 1278, productID: 33)],
        on: [],
        off: []
    )

    #expect(config.isAllowlisted(vendorID: 1278, productID: 33))
    #expect(!config.isAllowlisted(vendorID: 1278, productID: 34))
    #expect(!config.isAllowlisted(vendorID: 1279, productID: 33))
}
