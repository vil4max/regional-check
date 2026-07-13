import RegionalCheckData
import RegionalCheckStatus
import RegionalCheckDomain

let sharedProvider = UbillingAirAlertProvider()
let sharedFetchStatusUseCase = FetchAlertStatusUseCase(provider: sharedProvider)


