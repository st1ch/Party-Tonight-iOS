//
//  PromoterStatementTotalViewController.swift
//  PartyTonight
//
//  Created by Igor Kasyanenko on 19.11.16.
//  Copyright © 2016 Igor Kasyanenko. All rights reserved.
//

import UIKit

class PromoterStatementTotalViewController: UIViewController {

    @IBOutlet weak var statementTotalAmountLabel: UILabel!
    
    @IBOutlet weak var ticketsSalesAmountLabel: UILabel!
    
    @IBOutlet weak var bottlesSalesAmount: UILabel!
    
    @IBOutlet weak var tableSalesAmount: UILabel!
    
    @IBOutlet weak var refundsAmountLabel: UILabel!
    @IBOutlet weak var withdrawAmountLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
