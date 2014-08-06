//
//  Weather.swift
//
//  Created by Michael Pulsifer (U.S. Department of Labor) on 6/25/14.
//  Public Domain Software
//

import Foundation

protocol WeatherProtocol {
    func didCompleteForecast()
}

class Weather : GovDataRequestProtocol {
    
    var delegate: WeatherProtocol? = nil

    var latitude = ""
    var longitude = ""
    var feelsLike = PerceivedTemperature()
    var conversion = Conversions()

    // dailyForecast contains the weather data from NOAA, segregated by day
    struct dailyForecast {
        var forecastTime = [NSDate]()
        // dewPoint is an array of dictionaries (F, C)
        var dewPoint = [[String:Int]]()
        // heatIndex is an array of dictionaries (F, C)
        var heatIndex = [[String:Int]]()
        // windSpeed is an array of dictionaries (MPH, KPH)
        var windSpeed=[[String:Int]]()
        var cloudAmount = [Int]()
        var probabilityOfPrecipitation = [Int]()
        var humidity = [Int]()
        var windDirection = [Int]()
        var direction = [Int]()
        // temperature is an array of dictionaries (F, C)
        var temperature = [[String:Int]]()
        var windGust = [[String:Int]]()
        var windChill = [[String:Int]]()
        var windChillGust = [[String:Int]]()
        //var quantitativePrecipitation = [[String:Double]]()
        // weather conditions is an array of dictionaries.  First is the additive and the second is the condition.
        var weatherConditions = [[String:String]]()
        var maxHeatIndex = 79
        var minWindChillF = 50
        var minWindChillC = 10
        
    }
    
    var tempDict = Dictionary<String,String>()
    var tempArray = [String]()
    
    // Array of daily forecasts
    var sevenDayForecast = [dailyForecast]()
    

    
    
    // NOAA API setup
    var apiMethod = "MapClick.php"
    var arguments = Dictionary<String,String>()
        
    var forecastRequest: GovDataRequest = GovDataRequest(APIKey: "", APIHost: "http://forecast.weather.gov", APIURL: "")
    
    
    init(lat:String,long:String) {
        self.latitude = lat
        self.longitude = long
        self.arguments["lat"] = self.latitude
        self.arguments["lon"] = self.longitude
        self.arguments["FcstType"] = "digitalDWML"
        forecastRequest.responseFormat = "XML"
        forecastRequest.delegate = self
        
    }
    
    func refreshWeatherData () {
        arguments["lat"] = self.latitude
        arguments["lon"] = self.longitude
        forecastRequest.callAPIMethod(method: apiMethod, arguments: arguments)
    }
    
    func parseNOAADateTime(noaaDate: String) -> NSDate {
        /*
            This function takes the dateTime format provided by NOAA and returns a usable NSDate value
            This should be replaced with something much more efficient, should there be a better way
        */
        
        let format="yyyy-MM-dd HH:mm"
        
        //Sample dateTime format from NOAA:  2014-07-24T05:00:00-08:00
        func timeZoneAdjust (year: Int, month: Int, day: Int, hour: Int, hourModifier: Int, operator:NSString) -> (newYear:Int, newMonth:Int, newDay:Int, newHour:Int){
            /*
                This function evalutates the timezone offest provided by NOAA and makes the appropriate adjustment.
            
                This approach is a bit of a hack, but seemingly necessary because NSTimeZone's timezone by seconds from GMT ignores daylight savings time.
            */

            let tempHour = hour
            
            let monthDays = [29,31,28,31,30,31,30,31,31,30,31,30,31] // an array of the days in the month.  0 index is leap year February
            
            var newHour = hour
            var newDay = day
            var newMonth = month
            var newYear = year
            
            switch operator {
            case "+":
                newHour = (tempHour + hourModifier > 24 ? (tempHour+hourModifier)-24 : newHour)
                
            case "-":
                newHour = (tempHour - hourModifier < 0 ? 24+(tempHour - hourModifier) : newHour)
                
            default:
                // do stuff
                println("default!")
            }
            
            // Get the proper monthDays array index, accounting for leap year
            let monthIndex = (Int(year) % 4 == 0 ? 1 : newMonth)
            
            if tempHour > 24 {
                newDay += 1
                if newDay > monthDays[monthIndex] {
                    newMonth = 1 + (newMonth > 12 ? 0 : newMonth)
                    newDay = 1
                    newYear = newYear + (newMonth == 1 ? 1 : 0)
                }
            } else if tempHour < 0 {
                newDay -=  1
                if newDay < 1 {
                    newMonth = -1 + (newMonth < 1 ? 13 : newMonth)
                    newDay = monthDays[newMonth]
                    newYear = newYear - (newMonth == 12 ? 1 : 0)
                }
            }

            
            return (newYear, newMonth, newDay, newHour)
        }
        
        // break out the date and time pieces from the datetime string
        let year = noaaDate.substringToIndex(advance(noaaDate.startIndex, 4)).toInt()
        var slimmedStr = noaaDate
        slimmedStr = slimmedStr.substringFromIndex(advance(slimmedStr.startIndex, 5))
        let month = slimmedStr.substringToIndex(advance(slimmedStr.startIndex, 2)).toInt()
        slimmedStr = slimmedStr.substringFromIndex(advance(slimmedStr.startIndex, 3))
        let day = slimmedStr.substringToIndex(advance(slimmedStr.startIndex, 2)).toInt()
        slimmedStr = slimmedStr.substringFromIndex(advance(slimmedStr.startIndex, 3))
        let hour = slimmedStr.substringToIndex(advance(slimmedStr.startIndex, 2)).toInt()
        slimmedStr = slimmedStr.substringFromIndex(advance(slimmedStr.startIndex, 8))
        let operator = slimmedStr.substringToIndex(advance(slimmedStr.startIndex, 1))
        slimmedStr = slimmedStr.substringFromIndex(advance(slimmedStr.startIndex, 1))
        let hourModifier = slimmedStr.substringToIndex(advance(slimmedStr.startIndex, 2)).toInt()
        let minuteModifier = slimmedStr.substringFromIndex(advance(slimmedStr.startIndex, 3)).toInt()

        let adjustedDateTime = timeZoneAdjust(Int(year!), Int(month!), Int(day!), Int(hour!), Int(hourModifier!), operator)
        
        var dateFmt = NSDateFormatter()
        dateFmt.timeZone = NSTimeZone.defaultTimeZone()
        dateFmt.dateFormat = format
        let readableDate = "\(adjustedDateTime.newYear)-\(adjustedDateTime.newMonth)-\(adjustedDateTime.newDay) \(adjustedDateTime.newHour):00"
        return dateFmt.dateFromString(readableDate)
        
    }
    
    func didCompleteWithXML(results: XMLIndexer) {
        // now that we have the data from NOAA, the hard work begins
        var earliestTime = results["dwml"]["data"]["time-layout"]["start-valid-time"][0].element?.text
        
        var earliestTimeNS = parseNOAADateTime(earliestTime!)
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(.CalendarUnitDay, fromDate: earliestTimeNS)
        let dayZero = components.day
        
        //var recordIndex = 0
        var subRecordIndex = 0
        var previousDayIndex = -1
        var windSpeedMPH = 0
        var windSpeedGustMPH = 0
        
        // we should check for results["dwml"]["data"]["time-layout"]["start-valid-time"][recordIndex] as the SWXMLHash documentation suggests, but that crashes when you test an array index one higher than should be allowed.  For now, sticking with 168 records (7 full days)
        for recordIndex in 0...167 {
            let tempDateTimeString = results["dwml"]["data"]["time-layout"]["start-valid-time"][recordIndex].element?.text
            let thisDateTime = parseNOAADateTime(tempDateTimeString!)
            let tempDateTimeComponents = calendar.components(.CalendarUnitDay, fromDate: thisDateTime)
            let forecastIndex = tempDateTimeComponents.day - dayZero

            if forecastIndex < 0 {
                break
            }
            
            if recordIndex == 0 {
                if sevenDayForecast.count > 0 {
                    sevenDayForecast.removeAll(keepCapacity: false)
                }
            }
            
            if forecastIndex != previousDayIndex {
                subRecordIndex = 0
                previousDayIndex++
                sevenDayForecast += dailyForecast()
            } else {
                subRecordIndex++
            }

            sevenDayForecast[forecastIndex].forecastTime += thisDateTime

            // dewpoint
            let tempDewPointF = results["dwml"]["data"]["parameters"]["temperature"][0]["value"][recordIndex].element?.text?.toInt()
            let tempDewPointC = conversion.fahrenheitToCelsius(tempDewPointF!)
            sevenDayForecast[forecastIndex].dewPoint += ["F": Int(tempDewPointF!), "C":Int(tempDewPointC)]
            
            // heat index
            if results["dwml"]["data"]["parameters"]["temperature"][1]["value"][recordIndex].element?.text? {
                let tempHeatIndexF = results["dwml"]["data"]["parameters"]["temperature"][1]["value"][recordIndex].element?.text?.toInt()
                let tempHeatIndexC = conversion.fahrenheitToCelsius(tempHeatIndexF!)
                sevenDayForecast[forecastIndex].heatIndex += ["F": Int(tempHeatIndexF!), "C":Int(tempHeatIndexC)]
            } else {
                sevenDayForecast[forecastIndex].heatIndex += ["F": 0, "C":0]
            }

            // wind speed (sustained)
            if results["dwml"]["data"]["parameters"]["wind-speed"][0]["value"][recordIndex].element?.text? {
                let tempWindSpeedMPH = results["dwml"]["data"]["parameters"]["wind-speed"][0]["value"][recordIndex].element?.text?.toInt()
                windSpeedMPH = Int(tempWindSpeedMPH!)
                let tempWindSpeedKPH = conversion.milesToKilometers(tempWindSpeedMPH!)
                sevenDayForecast[forecastIndex].windSpeed += ["MPH": Int(tempWindSpeedMPH!), "KPH":Int(tempWindSpeedKPH)]
            } else {
                sevenDayForecast[forecastIndex].windSpeed += ["MPH": 0, "KPH":0]
            }
            
            // cloud amount (%)
            let tempCloudAmount = results["dwml"]["data"]["parameters"]["cloud-amount"]["value"][recordIndex].element?.text?.toInt()
            sevenDayForecast[forecastIndex].cloudAmount += tempCloudAmount!
            
            // probability of precipitation (%)
            let tempPOP = results["dwml"]["data"]["parameters"]["probability-of-precipitation"]["value"][recordIndex].element?.text?.toInt()
            sevenDayForecast[forecastIndex].probabilityOfPrecipitation += tempPOP!
            
            // relative humidity (%)
            let tempHumidity = results["dwml"]["data"]["parameters"]["humidity"]["value"][recordIndex].element?.text?.toInt()
            sevenDayForecast[forecastIndex].humidity += tempHumidity!

            // wind direction (degrees)
            let tempDirection = results["dwml"]["data"]["parameters"]["direction"]["value"][recordIndex].element?.text?.toInt()
            sevenDayForecast[forecastIndex].windDirection += tempDirection!
            
            // temperature
            let tempTemperatureF = results["dwml"]["data"]["parameters"]["temperature"][2]["value"][recordIndex].element?.text?.toInt()
            let tempTemperatureC = conversion.fahrenheitToCelsius(tempTemperatureF!)
            sevenDayForecast[forecastIndex].temperature += ["F": Int(tempTemperatureF!), "C":Int(tempTemperatureC)]

            // wind speed (gust)
            if results["dwml"]["data"]["parameters"]["wind-speed"][1]["value"][recordIndex].element?.text? {
                let tempWindGustMPH = results["dwml"]["data"]["parameters"]["wind-speed"][1]["value"][recordIndex].element?.text?.toInt()
                windSpeedGustMPH = tempWindGustMPH!
                let tempWindGustKPH = conversion.milesToKilometers(tempWindGustMPH!)
                sevenDayForecast[forecastIndex].windSpeed += ["MPH": Int(tempWindGustMPH!), "KPH":Int(tempWindGustKPH)]
            } else {
                sevenDayForecast[forecastIndex].windSpeed += ["MPH": 0, "KPH":0]
            }
            // quantitative precipitation (inches) (hourly)
            // had trouble casting the string values to Double.  Hope to get this resolved at some time.
            
            // Wind chill: T(wc) = 35.74 + 0.6215T - 35.75(V0.16) + 0.4275T(V0.16)
            sevenDayForecast[forecastIndex].windChill += feelsLike.calculateWindChill(Double(tempTemperatureF!), windInMPH: Double(windSpeedMPH))
            
            sevenDayForecast[forecastIndex].windChillGust += feelsLike.calculateWindChill(Double(tempTemperatureF!), windInMPH: Double(windSpeedGustMPH))
            
            
            // Determine the minimum wind chill for the day.  Since gusts are stronger than sustatined winds, only windSpeedGust is used
            sevenDayForecast[forecastIndex].minWindChillF = (sevenDayForecast[forecastIndex].windChillGust[subRecordIndex]["F"]! < sevenDayForecast[forecastIndex].minWindChillF ? sevenDayForecast[forecastIndex].windChillGust[subRecordIndex]["F"]! : sevenDayForecast[forecastIndex].minWindChillF)
            sevenDayForecast[forecastIndex].minWindChillC = (sevenDayForecast[forecastIndex].windChillGust[subRecordIndex]["C"]! < sevenDayForecast[forecastIndex].minWindChillC ? sevenDayForecast[forecastIndex].windChillGust[subRecordIndex]["C"]! : sevenDayForecast[forecastIndex].minWindChillC)
            
            // Weather conditions
            // we should check for results["dwml"]["data"]["parameters"]["weather"]["weather-conditions"][recordIndex]["value"] as the SWXMLHash documentation suggests, but that crashes when you test an array index one higher than should be allowed.  For now, sticking with 2 records (2 weather conditions attributes)
            for weatherConditionsIndex in 0...1 {
                switch results["dwml"]["data"]["parameters"]["weather"]["weather-conditions"][recordIndex]["value"][weatherConditionsIndex] {
                case .Element(let elem):
                        let additive = (results["dwml"]["data"]["parameters"]["weather"]["weather-conditions"][recordIndex]["value"][weatherConditionsIndex].element?.attributes["additive"]? ? results["dwml"]["data"]["parameters"]["weather"]["weather-conditions"][recordIndex]["value"][weatherConditionsIndex].element?.attributes["additive"] : "-")
                        let weatherType = results["dwml"]["data"]["parameters"]["weather"]["weather-conditions"][recordIndex]["value"][weatherConditionsIndex].element?.attributes["weather-type"]
                        sevenDayForecast[forecastIndex].weatherConditions += ["additive": additive!, "weatherType": weatherType!]
                case .Error(let error):
                    //println("error!")
                    let errorText = "Error!"
                default:
                    println("Did this just happen?")
                }
            }
            

            // prepare for the next record
            windSpeedMPH = 0
            windSpeedGustMPH = 0

        }
        // Let the delegate know our work is done.
        self.delegate?.didCompleteForecast()
    }


    
    
    func didCompleteWithDictionary(results: NSDictionary) {
        // nothing to do here
    }
    
    func didCompleteWithError(errorMessage: String) {
        println("error!")
    }
    

    
}

operator infix ** {}

func ** (num: Double, power: Double) -> Double{
    return pow(num, power)
}
