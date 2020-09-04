//
//  APIManager.swift
//  Snip
//
//  Created by Anthony Fernandez on 8/13/20.
//  Copyright © 2020 pictarine. All rights reserved.
//

import Foundation
import Combine
import KeychainAccess
import SwiftUI

class SyncManager: ObservableObject {
  
  public static let shared = SyncManager()
  
  private let keychainService = "com.pictarine.Snip"
  private let keychainAuthTokenKey = "oauth_github_key"
  
  @Published var isAuthenticated = false
  @Published var connectedUser : User?
  
  var stores: Set<AnyCancellable> = []
  var oauth : Oauth?
  
  var snippets : [SnipItem] = []
  
  private let clientId = "c4fd4a181bfc4089385b"
  private let clientSecret = "50273aed8a9f94cc7147cda776696b27207443e6"
  private let callbackURL = "snip://callback"
  private let addURL = "snip://add"
  static let oauthURL = URL(string: "https://github.com/login/oauth/authorize?client_id=c4fd4a181bfc4089385b&redirect_uri=snip://callback&scope=gist,user&state=snip")!
  
  func initialize() {
    
    let keychain = Keychain(service: keychainService)
    if let token = keychain[keychainAuthTokenKey] {
      
      oauth = Oauth(access_token: token)
      isAuthenticated = true
      
      DispatchQueue.global(qos: .utility).async { [weak self] in
        self?.requestUser()
      }
    }
    
    SnippetManager
    .shared
    .snipets
    .assign(to: \.snippets, on: self)
    .store(in: &stores)
  }
  
  func logout() {
    oauth = nil
    isAuthenticated = false
    connectedUser = nil
    
    do {
        let keychain = Keychain(service: keychainService)
        try keychain.remove(keychainAuthTokenKey)
    } catch let error {
        print("error: \(error)")
    }
  }
  
  func handleDeepLink(urls: [URL]) {
    let url = urls.first
    
    if let url = url,
      url.absoluteString.starts(with: callbackURL),
      let params = url.queryParameters{
      
      if let code = params["code"],
        let state = params["state"] {
        requestAccessToken(code: code, state: state)
      }
      else {
        print(url.absoluteString)
      }
      
    }
    
    if let url = url,
    url.absoluteString.starts(with: addURL),
    let params = url.queryParameters{
      
      if let code = params["code"],
        let from = params["from"],
        let title = params["title"],
        let tags = params["tags"] {
        
        let tagsArray = tags.fromBase64()!.split(separator: ";").map({ (substring) in
            return String(substring)
        })
        
        addSnippet(code: code.fromBase64()!, title: title.fromBase64()!, tags: tagsArray, from: from)
      }
      else {
        print(url.absoluteString)
      }
    }
    
  }
  
  func addSnippet(code: String, title: String, tags: [String], from: String) {
    
    var index = snippets.firstIndex(where: { (snip) -> Bool in
      snip.kind == .folder && snip.name == "StackOverflow"
    }) ?? -1
    
    if index >= 0 {
      print("Contains")
    }
    else {
      print("Does not contains")
      SnippetManager.shared.trigger(action: .addFolder(name: "StackOverflow"))
      
      index = snippets.firstIndex(where: { (snip) -> Bool in
        snip.kind == .folder && snip.name == "StackOverflow"
      }) ?? -1
    }
    
    SnippetManager.shared.trigger(action: .addSnippet(id: snippets[index].id, name: title, code: code, tags: tags))
  }
  
  func requestAccessToken(code: String, state: String) {
    requestToken(code: code, state: state)
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { (completion) in
        if case let .failure(error) = completion {
          print(error)
        }
      }, receiveValue: { [weak self] (oauth) in
        
        guard let this = self else { return }
        
        print(oauth.access_token)
        this.oauth = oauth
        this.isAuthenticated = true
        this.requestUser()
        
        let keychain = Keychain(service: this.keychainService)
        keychain[this.keychainAuthTokenKey] = oauth.access_token
        
      })
      .store(in: &stores)
  }
  
  func requestUser() {
    getUser()
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { (completion) in
        if case let .failure(error) = completion {
          print(error)
        }
      }, receiveValue: { [weak self] (user) in
        self?.connectedUser = user
      })
      .store(in: &stores)
  }
  
  func requestToken(code: String, state: String) -> AnyPublisher<Oauth, Error> {
    let bodyParams = [
      "client_id": clientId,
      "client_secret": clientSecret,
      "redirect_uri": callbackURL,
      "code": code,
      "state": state
    ]
    
    return API.run(Endpoint.token, HttpMethod.post, [:], bodyParams, [:], oauth)
  }
  
  func getUser() ->  AnyPublisher<User, Error> {
    
    let headerParams = [
      "Accept": "application/vnd.github.v3+json"
    ]
    
    return API.run(Endpoint.user, HttpMethod.get, [:], [:], headerParams, oauth)
  }
  
  func createGist(title: String, code: String) -> AnyPublisher<Gist, Error> {
    
    let headerParams = [
      "Accept": "application/vnd.github.v3+json"
    ]
    
    let bodyParams = [
      "files": [
        title: [ "content": code ]
      ],
      "description": title,
      "public": "\(false)"
      ] as [String : Any]
    
    return API.run(Endpoint.createGist, HttpMethod.post, [:], bodyParams, headerParams, oauth)
  }
  
  func updateGist(id: String, title: String, code: String) -> AnyPublisher<Gist, Error> {
     
     let headerParams = [
       "Accept": "application/vnd.github.v3+json"
     ]
     
     let bodyParams = [
       "files": [
         title: [ "content": code ]
       ],
       "description": title,
       "public": "\(false)"
       ] as [String : Any]
     
     return API.run(Endpoint.updateGist(id: id), HttpMethod.patch, [:], bodyParams, headerParams, oauth)
   }
}
