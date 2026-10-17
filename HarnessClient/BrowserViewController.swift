import UIKit
import WebKit

/// DeepSeek Harness 手机客户端:
/// 一个 WKWebView 外壳,加载运行在电脑上的 DeepSeek Harness 网页界面。
/// 首次启动会显示"连接到电脑"设置页,地址保存在 UserDefaults。
final class BrowserViewController: UIViewController {

    private enum Store {
        static let serverURLKey = "serverBaseURL"

        static func savedServerURL() -> URL? {
            guard let raw = UserDefaults.standard.string(forKey: serverURLKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !raw.isEmpty
            else { return nil }
            return normalizedURL(from: raw)
        }

        static func normalizedURL(from raw: String) -> URL? {
            var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { return nil }
            let lower = text.lowercased()
            if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
                text = "http://" + text
            }
            guard let url = URL(string: text),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  let host = url.host, !host.isEmpty
            else { return nil }
            return url
        }
    }

    // MARK: - UI

    private var webView: WKWebView!
    private let toolbar = UIToolbar()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var reloadItem: UIBarButtonItem!
    private var settingsItem: UIBarButtonItem!

    private var settingsPanel: UIView?
    private var urlField: UITextField?

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupWebView()
        setupToolbar()

        if let url = Store.savedServerURL() {
            loadServerURL(url)
        } else {
            showSettingsPanel(firstRun: true)
        }
    }

    // MARK: - 布局

    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = WKWebsiteDataStore.default()

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupToolbar() {
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.barTintColor = .secondarySystemBackground
        view.addSubview(toolbar)

        reloadItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(reloadTapped)
        )
        settingsItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let fixed = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixed.width = 24
        spinner.hidesWhenStopped = true
        let spinnerItem = UIBarButtonItem(customView: spinner)
        toolbar.setItems([reloadItem, fixed, spinnerItem, flexible, settingsItem], animated: false)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    // MARK: - 加载

    private func loadServerURL(_ url: URL) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        spinner.startAnimating()
        webView.load(request)
    }

    @objc private func reloadTapped() {
        if let current = webView.url, webView.isLoading == false {
            loadServerURL(current)
        } else if let saved = Store.savedServerURL() {
            loadServerURL(saved)
        } else {
            showSettingsPanel(firstRun: false)
        }
    }

    @objc private func settingsTapped() {
        showSettingsPanel(firstRun: false)
    }

    // MARK: - 设置面板

    private func showSettingsPanel(firstRun: Bool) {
        guard settingsPanel == nil else { return }

        let container = UIView(frame: view.bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.backgroundColor = UIColor(white: 0, alpha: 0.45)

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        container.addSubview(card)

        let titleLabel = UILabel()
        titleLabel.text = "连接到电脑上的 DeepSeek Harness"
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let detailLabel = UILabel()
        detailLabel.numberOfLines = 0
        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .secondaryLabel
        detailLabel.text = """
        使用前请确认:
        1. 电脑上已启动 DeepSeek Harness
        2. 电脑上已运行桥接脚本 pc-bridge(见说明文档)
        3. 手机与电脑连接同一个 Wi-Fi

        输入电脑的局域网地址,例如:
        192.168.2.92:19390
        """

        let field = UITextField()
        field.placeholder = "例如:192.168.2.92:19390"
        field.borderStyle = .roundedRect
        field.keyboardType = .URL
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.clearButtonMode = .whileEditing
        field.textAlignment = .center
        field.delegate = self
        if let saved = Store.savedServerURL() {
            field.text = saved.absoluteString
        }

        let connectButton = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = firstRun ? "连接" : "保存并连接"
        config.cornerStyle = .medium
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        connectButton.configuration = config
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelSettingsTapped), for: .touchUpInside)
        cancelButton.isHidden = firstRun

        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel, field, connectButton, cancelButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(18, after: detailLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        for subview in [titleLabel, detailLabel, field, connectButton, cancelButton] {
            subview.translatesAutoresizingMaskIntoConstraints = false
        }

        view.addSubview(container)
        settingsPanel = container
        urlField = field

        NSLayoutConstraint.activate([
            card.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 28),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -28),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),

            field.heightAnchor.constraint(equalToConstant: 40),
            connectButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @objc private func connectTapped() {
        guard let text = urlField?.text, let url = Store.normalizedURL(from: text) else {
            let alert = UIAlertController(
                title: "地址无效",
                message: "请输入电脑的局域网地址,例如:\n192.168.2.92:19390",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "好的", style: .default))
            present(alert, animated: true)
            return
        }
        UserDefaults.standard.set(url.absoluteString, forKey: Store.serverURLKey)
        dismissSettingsPanel()
        loadServerURL(url)
    }

    @objc private func cancelSettingsTapped() {
        dismissSettingsPanel()
    }

    private func dismissSettingsPanel() {
        settingsPanel?.removeFromSuperview()
        settingsPanel = nil
        urlField?.resignFirstResponder()
        urlField = nil
    }

    // MARK: - 错误页

    private func showErrorPage() {
        let html = """
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body{font-family:-apple-system,-apple-system-font;padding:36px 28px;background:#0b1220;color:#e5e7eb;text-align:center}
          h2{font-size:21px;margin-bottom:14px}
          p{font-size:14px;color:#9ca3af;line-height:1.9;margin:4px 0}
          .hint{margin-top:26px;color:#cbd5f5}
        </style></head>
        <body>
          <h2>无法连接到电脑</h2>
          <p>请检查:</p>
          <p>1. 电脑上的 DeepSeek Harness 是否正在运行<br>
             2. 电脑上是否已运行桥接脚本 pc-bridge<br>
             3. 手机和电脑是否连接同一个 Wi-Fi<br>
             4. Windows 防火墙是否放行(勾选"专用网络")</p>
          <p class="hint">点击底部 ⟳ 重试,或点击 ⚙ 修改地址</p>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - UITextFieldDelegate

extension BrowserViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        connectTapped()
        return true
    }
}

// MARK: - WKNavigationDelegate / WKUIDelegate

extension BrowserViewController: WKNavigationDelegate, WKUIDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        spinner.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        spinner.stopAnimating()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        handleFailure(error)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        handleFailure(error)
    }

    private func handleFailure(_ error: Error) {
        spinner.stopAnimating()
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }
        showErrorPage()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // 让 window.open 打开的页面也在当前 WebView 中显示
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
