package main

import (
    "context"
    "flag"
    "fmt"
    "log"
    "runtime"
    "os"
    "strings"
    //"regexp"
    //"net"
    //"time"

//  "reflect"

    "github.com/kardianos/service"

    "krr-app-gitlab01.europe.mittalco.com/pait/modules/go/logging"

    "reading_from_scales/src/config"
    "reading_from_scales/src/scales"
    db "reading_from_scales/src/database"
)

var VERSION string = ""
var COMMIT string = ""
var BUILD_DATE string = ""
var _VERSION_ string = VERSION+" commit("+COMMIT+") build("+BUILD_DATE+")"
const processEntrySize = 568

var (
    mod_name       = "main"
    service_prefix = "ArcelorMittal."
    Log            *logging.File
    conf           *config.Config

    //cancels
    ctx context.Context
)

// Program structures.
// Define Start and Stop methods.
type program struct {
    exit chan struct{}
}

func (p *program) Start(s service.Service) error {
    // Start should not block. Do the actual work async
    Log.Save("i", mod_name+": program version: "+_VERSION_+" compiled as arch: "+compiled_application_architecture())
    go p.run()
    return nil
}

func (p *program) Stop(s service.Service) error {
    // Stop should not block. Return with a few seconds
    Log.Save("i", mod_name+": service stop")
    return nil
}

func (p *program) run() {
  ch_message := make(chan string, 255)
  ch_db_message := make(chan db.Kep_analytics_weight, 255)
  var _db db.Config

  go func() {
	for {
        select {
            case message := <-ch_message:
				msg := strings.Split(message, "|:|")
                if len(msg) == 2 {
                    fmt.Printf("%s\n", msg[1])
                    Log.Save(msg[0], msg[1])
                }
			default:
        }
    }
  }()

  if conf.Database.Enable {
    // write to database
    _db = *db.New(&conf.Database, conf.App.Log.Enable, conf.App.Log.Level, ch_message, ch_db_message)
    _db.Run()
  }

  for _, scale := range conf.Scales {
	if scale.Enable {
		_scale := *scales.New(&scale, conf.App.Log.Enable, conf.App.Log.Level, ch_message, ch_db_message)
		_scale.Run()
	}
  }
}

func main() {
    svcFlag := flag.String("s", "", "Control the system service.")
    flag.Parse()
    var err error
    Log = logging.New()

    if conf, err = config.New(Log.GetPath(), Log.GetName()); err != nil {
        Log.Save("e",  err.Error())
        os.Exit(1)
    }

    if conf.App.Log.Enable {
        Log.Save("d", mod_name+": service command: "+fmt.Sprintf("%#v", *svcFlag))
    }

    svcConfig := &service.Config{
        Name:        service_prefix + conf.App.Service.Name,
        DisplayName: service_prefix + conf.App.Service.Display_name,
        Description: conf.App.Service.Description,
    }

    prg := &program{}
    s, err := service.New(prg, svcConfig)
    if err != nil {
        Log.Save("e", mod_name+": create servce: "+err.Error())
        log.Fatal(err)
    }
    ctx = context.Background()

    if len(*svcFlag) != 0 {
        err := service.Control(s, *svcFlag)
        if conf.App.Log.Enable {
            Log.Save("d", mod_name+": service command: "+fmt.Sprintf("%#v", *svcFlag))
        }
        if err != nil {
            fmt.Printf("valid actions: %q\n", service.ControlAction)
            Log.Save("e", mod_name+": valid actions: "+fmt.Sprintf("%q", service.ControlAction)+"  error: "+err.Error())
            log.Fatal(err)
            return
        }
        return
    }

    _status, err := s.Status()
    if conf.App.Log.Enable {
        Log.Save("d", mod_name+": service status: "+fmt.Sprintf("%d", _status))
    }
    //  if err == nil && _status == 1 {
    //      return
    //  }

    err = s.Run()
    if err != nil {
        Log.Save("e", mod_name+": "+err.Error())
        log.Fatal(err)
        return
    }
}

func isWindows() bool {
    if runtime.GOOS == "windows" {
        return true
    }
    return false
}

func isLinux() bool {
    if runtime.GOOS == "linux" {
        return true
    }
    return false
}

func compiled_application_architecture() string {
    switch arch := runtime.GOARCH; arch {
    case "386":
        return "x32"
    case "amd64":
        return "x64"
    default:
        return ""
    }
}
