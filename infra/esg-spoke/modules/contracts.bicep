@allowed([true])
param validSecurity bool
@allowed([true])
param validGrounding bool
@allowed([true])
param validModels bool
@allowed([true])
param validActivation bool
output valid bool = validSecurity && validGrounding && validModels && validActivation
