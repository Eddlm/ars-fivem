# Traffic Control

This one is simple, it lets you control traffic levels globally.


# Default or Set

The `tControlDefault <X.X|nil>` convar allows you to establish a default, and change that default live with `setr`. `nil` means the **no default control** of traffic. It will not apply multipliers or anything, it will be like traffic control is off.

# TriggerServerEvent

Other scripts can use `TriggerServerEvent('traffic_control:requestDensity', value, reason, requestKey)` to have Traffic Control set its target to your requested multiplier, until you set it again with `nil` as value, which implies you want to lift control. 

Two things: 
- The `requestKey`  is the identifier to add, update or remove your request. I'd use `GetCurrentResourceName()`.
- Traffic control honors **the lowest traffic** of all requests.

### Example calls:
- `TriggerServerEvent('traffic_control:requestDensity', 0.1, 'Race needs low traffic', GetCurrentResourceName())`
- `TriggerServerEvent('traffic_control:requestDensity', nil, 'Finished race', GetCurrentResourceName())`


## Convars

- `setr tControlDefault <X.X|nil>` - setr tControlDefault 0.5
- `setr tControlPrintRequests <true|false>` - setr tControlPrintRequests true