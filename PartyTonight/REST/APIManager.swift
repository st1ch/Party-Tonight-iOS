//
//  APIManager.swift
//  PartyTonight
//
//  Created by Igor Kasyanenko on 30.10.16.
//  Copyright © 2016 Igor Kasyanenko. All rights reserved.
//

import Foundation
import RxSwift
import ObjectMapper
import RxAlamofire
import SwiftyJSON
import Alamofire

enum Result<Value> {
    case Success(Value)
    case Failure(Error)
}
enum APIError: Error {
    case CannotParse(String)
    case UnsuccessfulSignup(String)
    case UnsuccessfulSignin(String)
    case BadStatusCode(String)
}


extension APIError: CustomStringConvertible {
    
    var description: String {
        switch self {
            
        case .UnsuccessfulSignup(let val):
            return  val;
        case .UnsuccessfulSignin(let val):
            return  val;
        case .BadStatusCode(let val):
            return  val;
        case .CannotParse(let val):
            return  val;
            //default: return "Undefined error";
            
        }
    }
}



class APIManager{
    static let sharedAPI = APIManager()
    
    var authToken:Token?{
        get{
            return userToken
        }
        set(newVal){
            userToken?.invalidate()
            userToken = newVal
            userToken?.save()
        }
    }
    
   private var userToken: Token? = Token()
    
    //
    
    
    struct Constants {
        static let baseURL = "http://localhost:8080/"
        //static let baseURL = "http://45.55.226.134:8080/partymaker/"
    }
    
    enum PromoterPath: String {
        case SignUp = "maker/signup"
        case SignIn = "signin"
        case Logout = "logout"
        case CreateEvent = "maker/event/create"
        case GetEvents = "maker/event/get"
        case GetRevenue = "maker/event/revenue"
        case GetBottles = "maker/event/bottles"
        case GetTables = "maker/event/tables"
        case GetTotal = "maker/event/total"
        case Image = "maker/event/image"
        
        var path: String {
            return Constants.baseURL + rawValue
        }
    }
    
    enum GoerPath: String {
        case SignUp = "dancer/signup"
        case SignIn = "signin"
        case GetEvents = "dancer/event/get"
        case Logout = "logout"
        var path: String {
            return Constants.baseURL + rawValue
        }
    }
    
    enum PurchasesPath: String {
        case ValidateBooking = "dancer/event/validate_booking"
        case GetInvoices = "dancer/event/get_invoices"
        case PostInvoices = "dancer/event/invoices"
        case ConfirmInvoices = "dancer/event/confirm_invoices"
        var path: String {
            return Constants.baseURL + rawValue
        }
    }
    

    
    
    
    private let successfulStatusCodes = 200...226;
    
    
    func event(create event: Event) -> Observable<Result<Int>> {
        
        print("creating event")
      //  print(JSON(Mapper<Event>().toJSON(event)).rawString())
        
        let headers = (userToken?.token != nil) ? ["x-auth-token": userToken!.token!] : [:]
        return request(.post, PromoterPath.CreateEvent.path, parameters: Mapper<Event>().toJSON(event),   encoding:  JSONEncoding.default,  headers: headers  )
            .map({ (response) -> DataRequest  in

                
                return response.validate(statusCode: self.successfulStatusCodes)
            }).flatMap { response -> Observable<Result<Int>> in
                
                return Observable.just(Result.Success(201))
            }.catchError({ (err) -> Observable<Result<Int>> in
                return Observable.just(Result.Failure(APIError.BadStatusCode(err.localizedDescription)));
                
            })
        //.catchErrorJustReturn(Result.Failure(APIError.BadStatusCode("")))
    }
    
    
    func event(zip: String? = nil) -> Observable<Result<[Event]>> {
        var headers = (userToken?.token != nil) ? ["x-auth-token": userToken!.token!] : [:]
        var eventPath = PromoterPath.GetEvents.path;
        if let zipCode = zip{
            eventPath = GoerPath.GetEvents.path;
            if(zipCode != ""){
                headers["zip_code"] = zipCode;
                
            }
        }
        return request(.get, eventPath,  headers: headers  )
            .flatMap({ (response) -> Observable<Any> in
                return response.validate(statusCode: self.successfulStatusCodes).rx.json()
            }).map(JSON.init)
            .flatMap { json -> Observable<Result<[Event]>> in
                
                guard let events = Mapper<Event>().mapArray(JSONString: json.rawString() ?? "" ) else {
                    return Observable.just(Result.Failure(APIError.CannotParse("")))
                }
                return Observable.just(Result.Success(events))
            }.catchError({ (err) -> Observable<Result<[Event]>> in
                return Observable.just(Result.Failure(APIError.BadStatusCode(err.localizedDescription)));
                
            })
        //.catchErrorJustReturn(Result.Failure(APIError.BadStatusCode("")))
    }
    
    
    
    
    func signin(user: User)-> Observable<Result<Token>> {
        let credentials = user.email! + ":" + user.password!;
        let authorizationHeader = "Basic " + credentials.toBase64();
        let headers = ["Authorization": authorizationHeader]
        return request(.get, PromoterPath.SignIn.path, headers: headers)
            .flatMap({ (response) -> Observable<Any> in
                return response.validate(statusCode: self.successfulStatusCodes).rx.json()
            })
            .map(JSON.init)
            .flatMap { json -> Observable<Result<Token>> in
                guard let token = Mapper<Token>().map(JSONString: json.rawString() ?? "") else {
                    return Observable.just(Result.Failure(APIError.CannotParse("")))
                }
                print("Got token: \(token.token)")
                
                return Observable.just(Result.Success(token))
            }.catchError({ (err) -> Observable<Result<Token>> in
                print("login err api \(err)")
                return Observable.just(Result.Failure(APIError.UnsuccessfulSignin(err.localizedDescription)));
                
            })
        
        
        
        //
        //.catchErrorJustReturn(Result.Failure(APIError.UnsuccessfulSignin))
    }
    
    func signup(promoter: User)-> Observable<Result<Token>> {
        return request(.post, PromoterPath.SignUp.path, parameters: Mapper<User>().toJSON(promoter) , encoding:  JSONEncoding.default)
            .map { response  in
                return response.validate(statusCode: self.successfulStatusCodes)
            }.flatMap { response -> Observable<Result<Token>> in
                return self.signin(user: promoter)
            }.catchError({ (err) -> Observable<Result<Token>> in
                return Observable.just(Result.Failure(APIError.UnsuccessfulSignup(err.localizedDescription)));
                
            })
        
        
        //.catchErrorJustReturn(Result.Failure(APIError.UnsuccessfulSignup("")))
    }
    
    
    
    
    func signup(goer: User)-> Observable<Result<Token>> {
        //print("goer signup")
       // print(JSON(Mapper<User>().toJSON(goer)).rawString())
        return request(.post, GoerPath.SignUp.path, parameters: Mapper<User>().toJSON(goer) , encoding:  JSONEncoding.default)
            .map { response  in
                return response.validate(statusCode: self.successfulStatusCodes)
            }.flatMap { response -> Observable<Result<Token>> in
                
                return self.signin(user: goer)
            }.catchError({ (err) -> Observable<Result<Token>> in
                return Observable.just(Result.Failure(APIError.UnsuccessfulSignup(err.localizedDescription)));
                
            })
        
        // .catchErrorJustReturn(Result.Failure(APIError.UnsuccessfulSignup("")))
        
    }
    
    
    
    func logout()-> Observable<Result<Int>> {
        authToken?.invalidate()
        let headers = (userToken?.token != nil) ? ["x-auth-token": userToken!.token!] : [:]
        return request(.get, PromoterPath.Logout.path, headers: headers)
            .map { response  in
                return response.validate(statusCode: self.successfulStatusCodes)
            }.flatMap { response -> Observable<Result<Int>> in
                  return Observable.just(Result.Success(200));
            }.catchError({ (err) -> Observable<Result<Int>> in
                return Observable.just(Result.Failure(APIError.UnsuccessfulSignup(err.localizedDescription)));
                
            })
    }
    

    
    
    func revenue(getFor partyName: String) ->  Observable<Result<Revenue>> {
        var headers = (userToken?.token != nil) ? ["x-auth-token": userToken!.token!] : [:]
        headers["party_name"] = partyName
        return request(.get, PromoterPath.GetRevenue.path,  headers: headers  )
            .flatMap({ (response) -> Observable<Any> in
                return response.validate(statusCode: self.successfulStatusCodes).rx.json()
            }).map(JSON.init)
            .flatMap { json -> Observable<Result<Revenue>> in
                
                guard let revenue = Mapper<Revenue>().map(JSONString: json.rawString() ?? "" ) else {
                    return Observable.just(Result.Failure(APIError.CannotParse("")))
                }
                return Observable.just(Result.Success(revenue))
            }.catchError({ (err) -> Observable<Result<Revenue>> in
                print(err)
                
                return Observable.just(Result.Failure(APIError.BadStatusCode(err.localizedDescription)));
                
            })
    }
    
    func bottles(getFor partyName: String) ->  Observable<Result<[Bottle]>> {
        var headers = (userToken?.token != nil) ? ["x-auth-token": userToken!.token!] : [:]
        headers["party_name"] = partyName
        return request(.get, PromoterPath.GetBottles.path,  headers: headers  )
            .flatMap({ (response) -> Observable<Any> in
                return response.validate(statusCode: self.successfulStatusCodes).rx.json()
            }).map(JSON.init)
            .flatMap { json -> Observable<Result<[Bottle]>> in
                guard let bottles = Mapper<Bottle>().mapArray(JSONString: json.rawString() ?? "" ) else {
                    return Observable.just(Result.Failure(APIError.CannotParse("")))
                }
                return Observable.just(Result.Success(bottles))
            }.catchError({ (err) -> Observable<Result<[Bottle]>> in
                return Observable.just(Result.Failure(APIError.BadStatusCode(err.localizedDescription)));
                
            })
    }
    
    
    func tables(getFor partyName: String) ->  Observable<Result<[Table]>> {
        var headers = (userToken?.token != nil) ? ["x-auth-token": userToken!.token!] : [:]
        headers["party_name"] = partyName
        return request(.get, PromoterPath.GetTables.path,  headers: headers  )
            .flatMap({ (response) -> Observable<Any> in
                return response.validate(statusCode: self.successfulStatusCodes).rx.json()
            }).map(JSON.init)
            .flatMap { json -> Observable<Result<[Table]>> in
                guard let tables = Mapper<Table>().mapArray(JSONString: json.rawString() ?? "" ) else {
                    return Observable.just(Result.Failure(APIError.CannotParse("")))
                }
                return Observable.just(Result.Success(tables))
            }.catchError({ (err) -> Observable<Result<[Table]>> in
                return Observable.just(Result.Failure(APIError.BadStatusCode(err.localizedDescription)));
                
            })
    }
    
    
    func total(getFor partyName: String) ->  Observable<Result<Total>> {
        var headers = (userToken?.token != nil) ? ["x-auth-token": userToken!.token!] : [:]
        headers["party_name"] = partyName
        return request(.get, PromoterPath.GetTotal.path,  headers: headers  )
            .flatMap({ (response) -> Observable<Any> in
                return response.validate(statusCode: self.successfulStatusCodes).rx.json()
            }).map(JSON.init)
            .flatMap { json -> Observable<Result<Total>> in
                guard let revenue = Mapper<Total>().map(JSONString: json.rawString() ?? "" ) else {
                    return Observable.just(Result.Failure(APIError.CannotParse("can not parse response")))
                }
                return Observable.just(Result.Success(revenue))
            }.catchError({ (err) -> Observable<Result<Total>> in
                print(err)
                return Observable.just(Result.Failure(APIError.BadStatusCode(err.localizedDescription)));
                
            })
    }
    
    //payment
    
    struct JSONArrayEncoding: ParameterEncoding {
        private let array: [Parameters]
        
        init(array: [Parameters]) {
            self.array = array
        }
        
        func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
            var urlRequest = try urlRequest.asURLRequest()
            
            let data = try JSONSerialization.data(withJSONObject: array, options: [])
            
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            urlRequest.httpBody = data
            
            return urlRequest
        }
    }
    
    func transaction(bookings validatingBookings: [Booking]) -> Observable<Result<Transaction>> {
        print("validating booking, getting transaction")
        
        let parameters : [Parameters] = Mapper<Booking>().toJSONArray(validatingBookings)
        let headers = (userToken?.token != nil) ? ["x-auth-token": userToken!.token!] : [:]
        return request(.post, PurchasesPath.PostInvoices.path,  encoding: JSONArrayEncoding(array: parameters),  headers: headers  )
            .flatMap({ (response) -> Observable<Any> in
                return response.validate(statusCode: self.successfulStatusCodes).rx.json()
            }).map(JSON.init)
            .flatMap { json -> Observable<Result<Transaction>> in
                guard let bookings = Mapper<Transaction>().map(JSONString: json.rawString() ?? "") else {
                    return Observable.just(Result.Failure(APIError.CannotParse("can not parse response")))
                }
                return Observable.just(Result.Success(bookings))
                
            }.catchError({ (err) -> Observable<Result<Transaction>> in
                return Observable.just(Result.Failure(APIError.BadStatusCode(err.localizedDescription)));
            })
    }

    func confirm(transaction inputTransaction: Transaction) -> Observable<Result<Int>> {
        print("confirming transaction")
        let headers = (userToken?.token != nil) ? ["x-auth-token": userToken!.token!] : [:]
        return request(.post, PurchasesPath.PostInvoices.path, parameters: Mapper<Transaction>().toJSON(inputTransaction) , encoding:  JSONEncoding.default, headers: headers  )
            .flatMap({ (response) -> Observable<Data> in
                return response.validate(statusCode: self.successfulStatusCodes).rx.data()
            })
            .flatMap { json -> Observable<Result<Int>> in
                               return Observable.just(Result.Success(200))
                
            }.catchError({ (err) -> Observable<Result<Int>> in
                return Observable.just(Result.Failure(APIError.BadStatusCode(err.localizedDescription)));
            })
    }

    
    func validate(bookings validatingBookings: [Booking]) -> Observable<Result<[Booking]>> {
        print("validating booking")
        
        let parameters : [Parameters] = Mapper<Booking>().toJSONArray(validatingBookings)
        let headers = (userToken?.token != nil) ? ["x-auth-token": userToken!.token!] : [:]
        return request(.post, PurchasesPath.ValidateBooking.path,  encoding: JSONArrayEncoding(array: parameters),  headers: headers  )
            .flatMap({ (response) -> Observable<Any> in
                return response.validate(statusCode: self.successfulStatusCodes).rx.json()
            }).map(JSON.init)
            .flatMap { json -> Observable<Result<[Booking]>> in
                guard let bookings = Mapper<Booking>().mapArray(JSONString: json.rawString() ?? "" ) else {
                    return Observable.just(Result.Failure(APIError.CannotParse("can not parse response")))
                }
                return Observable.just(Result.Success(bookings))
                
            }.catchError({ (err) -> Observable<Result<[Booking]>> in
                return Observable.just(Result.Failure(APIError.BadStatusCode(err.localizedDescription)));
            })
    }

    
    
    func invoices(for bookings: [Booking]) ->  Observable<Result<[Transaction]>> {
        let headers = (userToken?.token != nil) ? ["x-auth-token": userToken!.token!] : [:]
        let parameters : [Parameters] = Mapper<Booking>().toJSONArray(bookings)
        return request(.post, PurchasesPath.GetInvoices.path , encoding: JSONArrayEncoding(array: parameters), headers: headers  )
            .flatMap({ (response) -> Observable<Any> in
                return response.validate(statusCode: self.successfulStatusCodes).rx.json()
            }).map(JSON.init)
            .flatMap { json -> Observable<Result<[Transaction]>> in
                guard let transactions = Mapper<Transaction>().mapArray(JSONString: json.rawString() ?? "" ) else {
                    return Observable.just(Result.Failure(APIError.CannotParse("")))
                }
                return Observable.just(Result.Success(transactions))
            }.catchError({ (err) -> Observable<Result<[Transaction]>> in
                return Observable.just(Result.Failure(APIError.BadStatusCode(err.localizedDescription)));
                
            })
    }

    
    
    
    
    
    func uploadData(images:[UIImage]) -> Observable<[String]>{
        return Observable.combineLatest(images.map { (img)  in
            uploadImage(image: img)
        }, {el in el})
    }
    
    
    func uploadImage(image:UIImage) ->  Observable<String>{
        return Observable<String>.create({observer in
            let parameters:[String:String] = [:]
            let headers = (self.userToken?.token != nil) ? ["x-auth-token": self.userToken!.token!] : [:]
            
            
            Alamofire.upload(multipartFormData: { multipartFormData in
                if let imageData = UIImageJPEGRepresentation(image, 0.8) {
                    multipartFormData.append(imageData, withName: "file", fileName: "file.jpg", mimeType: "image/jpg")
                }
                
                for (key, value) in parameters {
                    multipartFormData.append((value.data(using: .utf8))!, withName: key)
                }}, to: PromoterPath.Image.path, method: .post, headers: headers,
                    encodingCompletion: { encodingResult in
                        switch encodingResult {
                        case .success(let upload, _, _):
   
                            
                            upload.responseJSON { [weak self] response in
                                
                                guard self != nil else {
                                    return
                                }
                                
                               
                                guard response.result.error == nil else {
                                    print("error response")
                                    print(response.result.error!)
                                    return
                                }
                                if let value: Any = response.result.value {
                                    print("photo upload response");
                                    print(JSON(value).rawString());
                                    observer.onNext(JSON(value)["path"].stringValue)
                                }
                                
                            }
                        case .failure(let encodingError):
                            print("error:\(encodingError)")
                        }
            })
            
            
            return Disposables.create();
            
        })
        
    }
    
}
