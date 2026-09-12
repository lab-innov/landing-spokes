@allowed([true])
param validSecurity bool
@allowed([true])
param validSettings bool
@allowed([true])
param validActivation bool
output valid bool = validSecurity && validSettings && validActivation
