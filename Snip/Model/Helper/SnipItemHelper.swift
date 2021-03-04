//
//  SnipItemHelper.swift
//  Snip
//
//  Created by Anthony Fernandez on 8/6/20.
//  Copyright © 2020 pictarine. All rights reserved.
//

import Foundation


extension Array where Element == SnipItem {
  
  var allGist: [Element] {
    return self.flatternSnippets.filter( { $0.gistId != nil })
  }
  
  var allFavorites: [Element] {
    return self.flatternSnippets.filter( { $0.isFavorite })
  }
  
  func perTag(tag: String) -> [Element] {
    return self.flatternSnippets.filter( { $0.tags.contains(tag) })
  }
  
  var flatternSnippets: [Element] {
    var allSnippets : [Element] = []
    
    for snip in self {
      allSnippets.append(snip)
      
      allSnippets.append(contentsOf: snip.content.flatternSnippets)
    }
    
    return allSnippets
  }
  
  var onlyLocal: [Element] {
    var allSnippets : [Element] = []
    
    for snip in self {
      if snip.syncState != .synced {
        snip.content = snip.content.onlyLocal
        allSnippets.append(snip)
      }
    }
    
    return allSnippets
  }
}

