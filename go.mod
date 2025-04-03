module reading_from_scales

go 1.23.4

require (
	github.com/kardianos/service v1.2.2
	krr-app-gitlab01.europe.mittalco.com/pait/modules/go/logging v0.0.0-00010101000000-000000000000
)

require (
	github.com/denisenkom/go-mssqldb v0.12.3 // indirect
	github.com/golang-sql/civil v0.0.0-20190719163853-cb61b32ac6fe // indirect
	github.com/golang-sql/sqlexp v0.1.0 // indirect
	golang.org/x/crypto v0.0.0-20220622213112-05595931fe9d // indirect
	golang.org/x/sys v0.0.0-20210615035016-665e8c7367d1 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

replace krr-app-gitlab01.europe.mittalco.com/pait/modules/go/logging => ./src/logging
