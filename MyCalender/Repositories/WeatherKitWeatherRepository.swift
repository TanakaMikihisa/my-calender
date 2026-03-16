import Foundation
import CoreLocation

#if canImport(WeatherKit)
import WeatherKit
#endif

// MARK: - Protocol

protocol WeatherRepositoryProtocol {
    /// 指定日の天気を取得。位置は実装側で取得するかデフォルト地域を使用
    func fetchWeather(for date: Date) async throws -> Weather?
    /// 当日の天気と24時間分の時間別天気を取得（アプリ起動時など1回だけ呼ぶ想定）
    func fetchTodayWeatherWithHourly() async throws -> (Weather?, [HourlyWeatherItem])
}

// MARK: - WeatherKit 実装

/// WeatherKit を使う天気取得。iOS 16+ かつ App に WeatherKit  capability が必要
final class WeatherKitWeatherRepository: WeatherRepositoryProtocol {
    #if canImport(WeatherKit)
    private let service = WeatherService.shared
    #endif
    private let locationRepository: LocationRepositoryProtocol
    private let defaultLocation: CLLocation

    /// locationRepository は @MainActor のため、呼び出し元（例: View）で生成して渡す
    init(
        locationRepository: LocationRepositoryProtocol,
        defaultLocation: CLLocation = CLLocation(latitude: 35.68, longitude: 139.69)
    ) {
        self.locationRepository = locationRepository
        self.defaultLocation = defaultLocation
    }

    func fetchWeather(for date: Date) async throws -> Weather? {
        let location = await locationRepository.currentLocation() ?? defaultLocation
        return try await fetchWeather(for: date, location: location)
    }

    func fetchTodayWeatherWithHourly() async throws -> (Weather?, [HourlyWeatherItem]) {
        let location = await locationRepository.currentLocation() ?? defaultLocation
        return try await fetchTodayWeatherWithHourly(location: location)
    }

    func fetchWeather(for date: Date, location: CLLocation) async throws -> Weather? {
        #if canImport(WeatherKit)
        let weather = try await service.weather(for: location)
        let calendar = Calendar.current
        guard let day = weather.dailyForecast.forecast.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) else {
            return nil
        }
        let requestedHour = calendar.component(.hour, from: date)
        let sameDayHourly = weather.hourlyForecast.forecast.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let atHour = sameDayHourly.first { calendar.component(.hour, from: $0.date) == requestedHour }
        let tempCelsius: Double? = atHour.map { $0.temperature.converted(to: .celsius).value }
            ?? ((day.highTemperature.converted(to: .celsius).value + day.lowTemperature.converted(to: .celsius).value) / 2)
        let symbolName = atHour?.symbolName ?? day.symbolName
        let precipChance: Double? = atHour?.precipitationChance ?? day.precipitationChance
        return Weather(
            symbolName: symbolName,
            temperatureCelsius: tempCelsius,
            precipitationChance: precipChance
        )
        #else
        return nil
        #endif
    }

    /// 当日の天気と、当日分の時間別天気（0〜23時）を取得
    func fetchTodayWeatherWithHourly(location: CLLocation) async throws -> (Weather?, [HourlyWeatherItem]) {
        #if canImport(WeatherKit)
        let weather = try await service.weather(for: location)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let day = weather.dailyForecast.forecast.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) else {
            return (nil, [])
        }

        let todayHourly = weather.hourlyForecast.forecast
            .filter { calendar.isDate($0.date, inSameDayAs: today) }
        let byHour: [Int: (String, Double, Double)] = Dictionary(
            uniqueKeysWithValues: todayHourly.map { h in
                (calendar.component(.hour, from: h.date), (
                    h.symbolName,
                    h.temperature.converted(to: .celsius).value,
                    h.precipitationChance
                ))
            }
        )
        let currentHour = calendar.component(.hour, from: Date())
        let dailySymbol: String
        let dailyTemp: Double?
        let dailyPrecip: Double?
        if let t = byHour[currentHour] {
            dailySymbol = t.0
            dailyTemp = t.1
            dailyPrecip = t.2
        } else {
            let high = day.highTemperature.converted(to: .celsius).value
            let low = day.lowTemperature.converted(to: .celsius).value
            dailySymbol = day.symbolName
            dailyTemp = (high + low) / 2
            dailyPrecip = day.precipitationChance
        }
        let daily = Weather(
            symbolName: dailySymbol,
            temperatureCelsius: dailyTemp,
            precipitationChance: dailyPrecip
        )
        let hourly: [HourlyWeatherItem] = (0..<24).map { hour in
            if let t = byHour[hour] {
                return HourlyWeatherItem(hour: hour, symbolName: t.0, temperatureCelsius: t.1, precipitationChance: t.2)
            }
            return HourlyWeatherItem(
                hour: hour,
                symbolName: daily.symbolName,
                temperatureCelsius: daily.temperatureCelsius,
                precipitationChance: daily.precipitationChance
            )
        }
        return (daily, hourly)
        #else
        return (nil, [])
        #endif
    }
}
