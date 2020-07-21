import Flutter
import UIKit
import MessageUI
    
public class SwiftFlutterEmailSenderPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_email_sender", binaryMessenger: registrar.messenger())

        let instance = SwiftFlutterEmailSenderPlugin()

        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "send":
            sendMail(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func sendMail(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let email = parseArgs(call, result: result) else { return }

        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            result(FlutterError.init(code: "error",
                                     message: "Unable to get view controller!",
                                     details: nil)
            )
            return
        }

        if MFMailComposeViewController.canSendMail() {
            let mailComposerVC = MFMailComposeViewController()
            mailComposerVC.mailComposeDelegate = self

            mailComposerVC.setToRecipients(email.recipients)
            if let subject = email.subject {
                mailComposerVC.setSubject(subject)
            }
            mailComposerVC.setCcRecipients(email.cc)
            mailComposerVC.setBccRecipients(email.bcc)
            
            if let body = email.body {
                mailComposerVC.setMessageBody(body, isHTML: email.isHTML ?? false)
            }

            if let attachmentPaths = email.attachmentPaths {
                for path in attachmentPaths {
                    if let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                        mailComposerVC.addAttachmentData(
                            fileData,
                            mimeType: "application/octet-stream",
                            fileName: (path as NSString).lastPathComponent
                        )
                    }
                }
            }

            viewController.present(mailComposerVC,
                                   animated: true,
                                   completion: { result(nil) }
            )
        } else{
            var activityItems: [Any] = [];

            if let recipients = email.recipients {
                activityItems += recipients.map { NSURL(string: "mailto:\($0)")};
            }

            if let body = email.body {
                activityItems.append(body);
            }

            if let attachmentPaths = email.attachmentPaths {
                            for path in attachmentPaths {
                                if let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                    activityItems.append(fileData)
                                }
                            }
                        }
            let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = viewController.view
            activityViewController.excludedActivityTypes = [ UIActivity.ActivityType.assignToContact,
            UIActivity.ActivityType.print,
            UIActivity.ActivityType.addToReadingList,
            UIActivity.ActivityType.saveToCameraRoll,

            UIActivity.ActivityType(rawValue: "com.apple.reminders.RemindersEditorExtension"),
            UIActivity.ActivityType(rawValue: "com.apple.mobilenotes.SharingExtension"),
            UIActivity.ActivityType(rawValue: "com.google.Drive.ShareExtension")
            ]

            if #available(iOS 9, *) {
                activityViewController.excludedActivityTypes?.append(    UIActivity.ActivityType.openInIBooks)
            }

            if let subject = email.subject {
                activityViewController.setValue(subject, forKey: "Subject")
             }
            activityViewController.completionWithItemsHandler = { activity, completed, items, error in
                if !completed {
                    result(FlutterError.init(code: "not_available",
                                             message: "Failed to Send email",
                                             details: nil)
                    )
                    return
                }
                result(nil)
            }
                
            viewController.present(activityViewController, animated: true, completion: nil)

        }
    }

    private func parseArgs(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Email? {
        guard let args = call.arguments as? [String: Any?] else {
            result(FlutterError.init(code: "error",
                                     message: "args are not map!",
                                     details: nil)
            )
            return nil
        }

        return Email(
            recipients:  args[Email.RECIPIENTS] as? [String],
            cc: args[Email.CC] as? [String],
            bcc: args[Email.BCC] as? [String],
            body: args[Email.BODY] as? String,
            attachmentPaths: args[Email.ATTACHMENT_PATHS] as? [String],
            subject: args[Email.SUBJECT] as? String,
            isHTML:args[Email.IS_HTML] as? Bool
        )
    }
}

extension SwiftFlutterEmailSenderPlugin : MFMailComposeViewControllerDelegate {
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}

struct Email {
    static let SUBJECT = "subject"
    static let BODY = "body"
    static let RECIPIENTS = "recipients"
    static let CC = "cc"
    static let BCC = "bcc"
    static let ATTACHMENT_PATHS = "attachment_paths"
    static let IS_HTML = "is_html"

    let recipients: [String]?
    let cc: [String]?
    let bcc: [String]?
    let body: String?
    let attachmentPaths: [String]?
    let subject: String?
    let isHTML: Bool?
}
