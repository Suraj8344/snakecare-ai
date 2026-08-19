# Android emergency transports

SnakeCare exposes Android emergency hardware through the
`org.snakecare/emergency` Flutter method channel.

## Implemented

- The **Call 112** action opens the native phone dialer with `112`.
- **Prepare SOS SMS** opens the device messaging application with a verified
  gateway number and the current risk, symptoms, and GPS payload prefilled.
- **Open gateway dialer** opens a user-configured telephony gateway number.
  The user must place and end the call; normal Android apps cannot silently
  disconnect after one ring.
- **BLE SOS broadcast** starts `SosBleService`, an Android foreground service
  that advertises a compact, non-connectable manufacturer payload while a
  visible emergency notification is active.
- Android cellular signal level can be read after the applicable phone/location
  permission is granted.
- The SOS is always written to the encrypted Hive outbox before an optional BLE
  transport is attempted.

## Required configuration

The hospital or project operator must supply a real SMS/missed-call gateway
number in the Offline Emergency Center. Do not seed a public emergency number
as an SMS gateway unless the relevant authority has approved that workflow.

The receiving gateway must independently authenticate, deduplicate, timestamp,
and acknowledge messages. Opening the SMS application or dialer is not proof
that the message/call was delivered.

## Android permissions

Android 12 and newer request `BLUETOOTH_ADVERTISE` and `BLUETOOTH_CONNECT` when
BLE is first armed. Location/phone permission is used for GPS and signal-level
access. The foreground-service notification remains visible while BLE SOS is
active.

## BLE payload

The advertised payload is intentionally compact because BLE manufacturer data
is size-limited:

`SC1|<risk-score>|<latitude-x100>|<longitude-x100>`

It contains no name, phone number, medical passport, or detailed symptoms.
Receiving/relay applications must treat it as unverified emergency data.

## Platform limits

- Browsers cannot advertise BLE in the background; the web build reports BLE
  as unavailable.
- SMS and missed-call actions require user confirmation.
- A zero-signal user with no nearby relay device still requires satellite or
  dedicated radio hardware.
- Physical-device BLE, carrier, OEM battery-management, and gateway tests are
  required before production emergency claims are made.
