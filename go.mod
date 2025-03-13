module reading_from_scales

go 1.23.4

require (
	github.com/kardianos/service v1.2.2
	krr-app-gitlab01.europe.mittalco.com/pait/modules/go/logging v0.0.0-00010101000000-000000000000
)

require (
	golang.org/x/sys v0.0.0-20201015000850-e3ed0017c211 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

replace krr-app-gitlab01.europe.mittalco.com/pait/modules/go/logging => ./src/logging
