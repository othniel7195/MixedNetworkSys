//
//  ViewController.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/02/2019.
//  Copyright (c) 2021 wjszf. All rights reserved.
//

import UIKit
import Then

class ViewController: UIViewController {
    let provider = ApiTestEng().createProvider()
    let mixedProvider = ApiTestEng().createMixedProvider()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
//       let task = ApiTestEng().openHours(provider) { data, err in
//            if let err = err {
//                print(err)
//            } else {
//                print(data!)
//            }
//            print("==================")
//        }
//        task?.cancel()
        
        let task2 = ApiTestEng().openHoursMixed(mixedProvider) { data, err in
            print("==================")
            if let err = err {
                print(err)
            } else {
                print(data!)
            }
            print("==================")
        }
        task2?.cancel()
       
        
//        let sdata: Promise<Schedule> = ApiTestEng().openHoursNew(provider)
//        sdata.then { data in
//            print(data)
//            print("~~~~~~~~~~~~~~~~~~~~~")
//        }.onError { err in
//            print(err)
//            print("~~~~~~~~~~~~~~~~~~~~~~")
//        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
    }

}

