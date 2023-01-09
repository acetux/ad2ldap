# Script to convert a Microsoft AD CSV export to a LDAP LDIF

Generate the export via the Windows CMD:

```csvde -f ad-export.csv -s GERTZENSTEIN -d "dc=gertzenstein,dc=local" -p subtree -u```
