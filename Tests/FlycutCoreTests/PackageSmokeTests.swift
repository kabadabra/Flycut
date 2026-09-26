import XCTest
import FlycutCore

final class PackageSmokeTests: XCTestCase {
    func testClipValueAndPackageVersion() {
        let clip = Clip(
            id: UUID(uuidString: "D95486F6-EF25-4DCF-BC5A-1A39E4B28238")!,
            text: "exact text\n",
            pasteboardType: "public.utf8-plain-text",
            sourceAppName: nil,
            sourceBundleURL: nil,
            capturedAt: nil
        )

        XCTAssertEqual(clip.text, "exact text\n")
        XCTAssertEqual(FlycutVersion.current, "3.0.0")
    }
}
