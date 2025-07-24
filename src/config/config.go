package config

import (
    "os"
    "fmt"
    "regexp"
    "sort"
    "strings"

	"gopkg.in/yaml.v3"
)

const conf_preffix string = ".conf."
const config_d_dir string = "config.d"
const max_read_files = 1000
const file_separator = string(os.PathSeparator)

var (
	conf_ext = []string{"yml", "yaml"}
    mod_name = "config"
)

type Config struct {
	Database     Database `yaml:"database"`
	Scales       []Scale  `yaml:"scales"`
	App          App      `yaml:"app"`
}

type Database struct {
	Enable                        bool   `yaml:"enable"`
	Type                          string `yaml:"type"`
	Host                          string `yaml:"host"`
	Port                          string `yaml:"port"`
	Username                      string `yaml:"username"`
	Password                      string `yaml:"password"`
	Database                      string `yaml:"database"`
	Table                         string `yaml:"table"`
}

type App struct {
	Log            struct {
		Enable bool   `yaml:"enable"`
		Level  string `yaml:"level"`
	} `yaml:"log"`
	Service struct {
		Name         string `yaml:"name"`
		Display_name string `yaml:"display_name"`
		Description  string `yaml:"description"`
	} `yaml:"service"`
}

type Scale struct {
	Enable                     bool   `yaml:"enable"`
	Connection                 string `yaml:"connection"`
	Type                       string `yaml:"type"`
	Protocol                   string `yaml:"protocol"`
	Id_scale                   int    `yaml:"id_scale"`
	Command                    string `yaml:"command"`
	Parameter_position         int    `yaml:"parameter_position"`
	Coefficient                float64`yaml:"coefficient"`
	Disabled_parameters        string `yaml:"disabled_parameters"`
	Local_timestamp            bool   `yaml:"local_timestamp"`
	Read_cycle                 int    `yaml:"read_cycle"`
	Network         struct {
		Host               string `yaml:"host"`
		Port               int    `yaml:"port"`
		Protocol           string `yaml:"protocol"`
	} `yaml:"network"`
}

func New(_path string, filename string) (*Config, error) {
    var path_filename string
    for _, file_ext := range conf_ext {
        path_filename = _path + filename + conf_preffix + file_ext
        if check_dir_or_file_exists(path_filename) {
            break
        } else {
            path_filename = ""
        }
    }

    if len(path_filename) == 0 {
        return nil, fmt.Errorf("%s: file is not exist: '%s.{%s}'  path: '%s", mod_name, filename , strings.Join(conf_ext[:], ","), _path)
    }

    /* begin main config */
    var conf *Config
    /* read base configuration */
    raw, err := os.ReadFile(path_filename)
    if err != nil {
        return nil, fmt.Errorf("%s: %s", mod_name, err)
    }
    err = yaml.Unmarshal(raw, &conf)
    if err != nil {
        return nil, fmt.Errorf("%s: %s", mod_name, err)
    }
    /* end main config */

    /* begin config.d */
    /* the structure that will be moved to config.d is selected */
    type scales struct {
        Scales []Scale
    }
    var s scales

    for _, f := range get_config_d_files(_path) {
        /* reading configurations from confid.d */
        raw, err := os.ReadFile(f)
        if err != nil {
            continue
        }

        err = yaml.Unmarshal(raw, &s)
        if err != nil {
            continue
        }
        /* adding configuration to the main structure */
        conf.Scales = append(conf.Scales, s.Scales...)
    }
    /* end config.d */

    return conf, nil
}

func get_config_d_files(_path string) ([]string) {
    count_files := 0
    var files []string

    for _, file := range list_files(_path + config_d_dir) {
        match, _ := regexp.MatchString("(?i)\\.conf\\.(yml|yaml)$", file)
        if ! match {
            continue
        }
        if count_files > max_read_files {
            break
        }
        count_files++

        files = append(files, _path + config_d_dir + file_separator + file)
    }

    return files
}

func check_dir_or_file_exists(fullpath string) bool {
  if _, err := os.Stat(fullpath); os.IsNotExist(err) {
        if check_dir(fullpath) == "d" {
            /*
            m := fmt.Sprintf("%s: directory is not exist: '%s'", mod_name, fullpath)
            fmt.Printf("%s\n", m)
            */
        }
        if check_dir(fullpath) == "f" {
            /*
            m := fmt.Sprintf("%s: file is not exist: '%s'", mod_name, fullpath)
            fmt.Printf("%s\n", m)
            */
        }
    return false
  } else {
        if check_dir(fullpath) == "d" {
            /*
            m := fmt.Sprintf("%s: directory already exists: '%s'", mod_name, fullpath)
            fmt.Printf("%s\n", m)
            */
        }
        if check_dir(fullpath) == "f" {
            /*
            m := fmt.Sprintf("%s: file already exists: '%s'", mod_name, fullpath)
            fmt.Printf("%s\n", m)
            */
        }
    return true
  }
}

func check_dir(fullpath string) string {
   fileInfo, err := os.Stat(fullpath)
   if err != nil {
        /*
        m := fmt.Sprintf("%s: %s", mod_name, err.Error())
        fmt.Printf("%s\n", m)
        */
        return ""
   }
   if fileInfo.Mode().IsDir() {
        /*
        m := fmt.Sprintf("%s: check directory:  path: '%s'  isDir: true", mod_name, fullpath)
        fmt.Printf("%s\n", m)
        */
        return "d"
   } else {
        return "f"
   }
}

func list_files(fullpath string) []string {
  var _files []string
  if ! check_dir_or_file_exists(fullpath) {
    return _files
  }
  f, err := os.Open(fullpath)
  if err != nil {
    /*
    m := fmt.Sprintf("%s: %s", mod_name, err.Error())
    fmt.Printf("%s\n", m)
    */
  }
  files, err := f.Readdir(0)
  if err != nil {
    /*
    m := fmt.Sprintf("%s: %s", mod_name, err.Error())
    fmt.Printf("%s\n", m)
    */
  }

  /* sort ascending modtime */
  /*
  sort.Slice(files, func(i,j int) bool{
    return files[i].ModTime().Before(files[j].ModTime())
  })
  */

  for _, v := range files {
    /*
    m := fmt.Sprintf("%s: list files generate:  file: %s  mod time: %s:  isDir: %t", mod_name, v.Name(), v.ModTime(), v.IsDir())
    fmt.Printf("%s\n", m)
    */
    if ! v.IsDir() {
        _files = append(_files, v.Name())
    }
  }

  /* sort string */
  sort.Sort(sort.StringSlice(_files))

  return _files
}
