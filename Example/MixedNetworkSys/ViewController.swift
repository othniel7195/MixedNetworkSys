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
        ApiTestEng().openHours(provider) { sdata, err in
            
        }
        
        
        let sdata: Promise<Schedule> = ApiTestEng().openHoursNew(provider)
        sdata.then { data in
            
        }.onError { error in
            
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
    }

}

