//
//  MarkdownHTMLViewer.swift
//  Snip
//
//  Created by Anthony Fernandez on 8/24/20.
//  Copyright © 2020 pictarine. All rights reserved.
//

import Foundation
import SwiftUI
import WebKit
import Down
import Combine

struct MarkdownHTMLViewer: NSViewRepresentable {
  
  @ObservedObject var viewModel: MarkdownHTMLViewerModel
  
  class Coodinator: NSObject, WKNavigationDelegate {
    
    private func encodeStringTo64(fromString: String) -> String? {
        let plainData = fromString.data(using: .utf8)
        return plainData?.base64EncodedString(options: [])
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      guard let path = Bundle.main.path(forResource: "md", ofType: "css") else {
          return
      }
      
      let cssString = try! String(contentsOfFile: path).components(separatedBy: .newlines).joined()
      
      let cssStyle = """
          javascript:(function() {
          var parent = document.getElementsByTagName('head').item(0);
          var style = document.createElement('style');
          style.type = 'text/css';
          style.innerHTML = window.atob('\(encodeStringTo64(fromString: cssString)!)');
          parent.appendChild(style)})()
      """
      
      let cssScript = WKUserScript(source: cssStyle, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
      
      webView.configuration.userContentController.addUserScript(cssScript)
    }

  }

  func makeCoordinator() -> Coodinator {
      return Coodinator()
  }

  
  fileprivate func setContent(_ webView: WKWebView, code: String, mode: Mode) {
    
    var htmlSource = ""
    
    if mode == CodeMode.html.mode() {
      
      if !code.contains("<head>") {
        htmlSource = "<head><meta name=\"viewport\" content=\"initial-scale=1.0\" /></head>" + code
      }
      else {
        htmlSource = code
      }
      
    }
    else if mode == CodeMode.markdown.mode() {
      
      let down = Down(markdownString: code)

      if let html = try? down.toHTML() {
          htmlSource = "<head><meta name=\"viewport\" content=\"initial-scale=1.0\" /></head>" +  "<article class=\"markdown-body\">\(html)</article>"
      }
    }
    
    webView.loadHTMLString(htmlSource, baseURL: nil)
  }
  
  func makeNSView(context: Context) -> WKWebView {
    
    let preferences = WKPreferences()
    
    let configuration = WKWebViewConfiguration()
    configuration.preferences = preferences
    
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.setValue(false, forKey: "drawsBackground")
    webView.allowsMagnification = false
    webView.navigationDelegate = context.coordinator
    
    
    setContent(webView, code: viewModel.code, mode: viewModel.mode)
    return webView
  }
  
  func updateNSView(_ codeMirrorView: WKWebView, context: Context) {
    setContent(codeMirrorView, code: viewModel.code, mode: viewModel.mode)
  }
}

final class MarkdownHTMLViewerModel: ObservableObject {
  
  @Published var code: String = ""
  @Published var mode: Mode = CodeMode.text.mode()
  
  var cancellable: AnyCancellable?
  
  init(snipItem: AnyPublisher<SnipItem?, Never>) {
    cancellable = snipItem
      .sink { [weak self] (snipItem) in
        guard let this = self,
          let snipItem = snipItem
        else { return }
        
        this.code = snipItem.snippet
        this.mode = snipItem.mode
    }
  }
}
