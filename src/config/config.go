package config

import (
	"io/ioutil"
	"os"
	"fmt"

	"gopkg.in/yaml.v3"
)

const conf_preffix string = ".conf."

var (
	conf_ext = []string{"yml", "yaml"}
)

type Config struct {
	Database     Database `yaml:"database"`
	Scales       Scales   `yaml:"scales"`
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

type Scales struct {
	Enable             bool   `yaml:"enable"`
	Connection         string `yaml:"connection"`
	Type               string `yaml:"type"`
	Protocol           string `yaml:"protocol"`
	Id_scale           int    `yaml:"id_scale"`
	Command            string `yaml:"command"`
	Coefficient        int    `yaml:"coefficient"`
	Read_cycle         int    `yaml:"read_cycle"`
	Network         struct {
		Host               string `yaml:"host"`
		Port               int    `yaml:"port"`
		Protocol           string `yaml:"protocol"`
	} `yaml:"network"`
}

func New(_path string, filename string) (*Config, error) {
	var err error
	if filename, err = checkConfFile(_path, filename); err != nil {
	    return nil, err
	}

	var conf *Config
	raw, err := ioutil.ReadFile(_path + filename)
	if err != nil {
		return nil, fmt.Errorf("config: file is not exist: '%s'  path: '%s", filename, _path)
	}
	err = yaml.Unmarshal(raw, &conf)
	if err != nil {
		return nil, err
	}
	return conf, nil
}

func checkConfFile(_path string, filename string) (string, error) {
	for _, value := range conf_ext {
		if _, err := os.Stat(_path + filename + conf_preffix + value); err == nil {
			filename = filename + conf_preffix + value
                        break
                } else if os.IsNotExist(err) {
                        filename = filename + conf_preffix + value
                        return "", fmt.Errorf("config: file is not exist: '%s'  path: '%s", filename, _path)
                }
        }

	return filename, nil
}
