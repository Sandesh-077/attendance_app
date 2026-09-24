# CA Attendance — School Deployment Checklist

## Pre-deployment
- [ ] Production APK built successfully
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] Correct Android application ID confirmed
- [ ] Production signing verified
- [ ] Firestore production rules deployed
- [ ] Required Firestore indexes deployed
- [ ] `appConfig/currentVersion` configured
- [ ] `updateUrl` points to the official school APK distribution location
- [ ] Administrator production account tested
- [ ] Teacher production account tested
- [ ] Teacher/class assignments verified
- [ ] Real-device installation tested

## Initial rollout
- [ ] Deploy to an administrator
- [ ] Deploy to a small teacher group first
- [ ] Verify login
- [ ] Verify assigned classes
- [ ] Verify roster
- [ ] Verify attendance
- [ ] Verify reports
- [ ] Verify Attendance History
- [ ] Verify update check

## Full rollout
- [ ] Provide official APK/download location
- [ ] Provide Teacher Quick Start Guide
- [ ] Provide support contact
- [ ] Confirm all intended teachers have accounts
- [ ] Confirm teacher assignments
- [ ] Monitor the first week for issues

## Backup and security
- [ ] Never distribute the release keystore or `key.properties`.
- [ ] Never share Firebase private credentials.
- [ ] Preserve the signing keystore securely; future APK updates must use the same signing identity.
- [ ] Maintain a secure backup of release signing material.
