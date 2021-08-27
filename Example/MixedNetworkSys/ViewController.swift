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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let provider = ApiTestEng().createProvider()
        ApiTestEng().openHours(provider) { data, err in
            if let err = err {
                print(err)
            } else {
                print(data!)
            }
            print("==================")
        }
        
       
        
        let sdata: Promise<Schedule> = ApiTestEng().openHoursNew(provider)
        sdata.then { data in
            print(data)
            print("~~~~~~~~~~~~~~~~~~~~~")
        }.onError { err in
            print(err)
            print("~~~~~~~~~~~~~~~~~~~~~~")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
    }

}

