//
//  perceivedTemperature.swift
//  Weather Test App
//
//  Created by Michael Pulsifer (U.S. Department of Labor) on 8/3/14.
//  Public Domain Software
//

import Foundation

class PerceivedTemperature {
    
    var calculatedWindChillF = 51.0
    var calculatedWindChillC = 11.0
    var calculatedHeatIndexF = 79.0
    var calculatedHeatIndexC = 26
    var conversion = Conversions()
    
    init () {
        self.calculatedWindChillF = 51.0
        self.calculatedWindChillC = 11.0

    }
    
    func calculateHeatIndex(tempInF: Double, humidity:Double) -> [String:Int] {
        if tempInF >= 80.0 {
            // Broke the formula up in pieces since its orginal incarnation was causing problems with Xcode
            calculatedHeatIndexF = -42.379 + (2.04901523 * tempInF)
            calculatedHeatIndexF += 10.14333127 * humidity
            calculatedHeatIndexF -= 0.22475541 * tempInF * humidity
            calculatedHeatIndexF -= 6.83783 * pow(10, -3) * pow(tempInF,2)
            calculatedHeatIndexF -= 5.481717 * pow(10,-2) * pow(humidity,2)
            calculatedHeatIndexF += 1.22874 * pow(10, -3) * pow(tempInF,2) * humidity
            calculatedHeatIndexF += 8.5282 * pow(10,-4) * tempInF * pow(humidity,2)
            calculatedHeatIndexF -= 1.99 * pow(10,-6) * pow(tempInF, 2) * pow(humidity, 2)
            
            calculatedHeatIndexC = conversion.fahrenheitToCelsius(Int(calculatedHeatIndexF))
            
        }
        return ["F":Int(calculatedHeatIndexF), "C":calculatedHeatIndexC]
    }

    func calculateWindChill(tempInF:Double, windInMPH:Double) -> [String:Int] {
        if tempInF < 50.0 && windInMPH > 3.0 {
            let tempTempF = Int(tempInF)
            let tempTempC = conversion.fahrenheitToCelsius(tempTempF)
            let tempInC = Double(tempTempC)
            let tempWindMPH = Int(windInMPH)
            let tempWindKPH = conversion.milesToKilometers(tempWindMPH)
            let windInKPH = Double(tempWindKPH)
            calculatedWindChillF = 35.74 + 0.6215 * tempInF - 35.75 * (windInMPH**0.16) + 0.4275 * tempInF * pow(windInMPH,0.16)
            calculatedWindChillC = 13.12 + 0.6215 * tempInC - 35.75 * (windInKPH**0.16) + 0.4275 * tempInC * pow(windInKPH,0.16)
        }
        return ["F":Int(calculatedWindChillF), "C":Int(calculatedWindChillC)]
    }
}


