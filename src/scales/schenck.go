/*

    протокол: SCHENCK Poll Protocol (DDP 8785)
    информация: bvh2141gb.pdf
    контроллер: DISOMAT B plus

*/

package scales

import (
  "fmt"
  "regexp"
  "strings"
  "strconv"

  db "reading_from_scales/src/database"
)


func (c *Config) Processing_schenck(message string) {
  msg := regexp.MustCompile("(?m).*" + c.Command + "(.*)" + "#.*$").ReplaceAllString(message, "$1")
  msg = regexp.MustCompile("(?m)[\\s" + string(STX) + string(ETX) + "]+").ReplaceAllString(msg, "$1")
  values := strings.Split(msg, "#")
  index := c.Parameter_position-1

  if len(values) == 0 { return }

  if c.Coefficient == 0 {
    c.Coefficient = 1
  }

  if index > len(values) {
    c.ch_message <- fmt.Sprintf("w|:|%s: Processing Schenck: parameter position: %d  is greater than parameters: %d", mod_name, index, len(values))
    return
  }

  kaw := db.Kep_analytics_weight{}
  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Schenck message: '%v'", mod_name, msg)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Schenck values: '%#v'", mod_name, values)
  }

  kaw.Id_scales = fmt.Sprintf("%d", c.Id_scale)
  kaw.Timestamp = c.get_datetime("")
/*
  if ! c.check_disabled_parameter(`weight`) && len(values) >= index {
    if _, err := strconv.Atoi(c.get_value(values[index])); err == nil {
        kaw.Weight = c.get_value(values[index])
    }
  }
*/
  if ! c.check_disabled_parameter(`weight_platform_1`) && len(values) >= index {
    if _, err := strconv.Atoi(c.get_value(values[index])); err == nil {
        kaw.Weight_platform_1 = c.get_value(values[index])
    }
  }
  if ! c.check_disabled_parameter(`weight_stabilized_1`) && len(values) >= index {
    kaw.Weight_stabilized_1 = "1"
  }

  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Schenck  message: %#v", mod_name, msg)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Schenck  values: %#v", mod_name, values)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Schenck  id_scale: %s  timestamp: %s", mod_name, kaw.Id_scales, kaw.Timestamp)
//    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Schenck  id_scale: %s  weight: %s", mod_name, kaw.Id_scales, kaw.Weight)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Schenck  id_scale: %s  weight_platform_1: %s", mod_name, kaw.Id_scales, kaw.Weight_platform_1)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Schenck  id_scale: %s  weight_stabilized_1: %s", mod_name, kaw.Id_scales, kaw.Weight_stabilized_1)
  }

  select {
    case c.ch_db_message <- kaw:
    default:
  }
}

func (c *Config) hash_bcc(buf []byte) (string, error) {
  total := buf[0]
  for i := 1; i < len(buf); i++ {
    total = total ^ buf[i]
    if DEBUG.enable {
        c.ch_message <- fmt.Sprintf("d|:|%s: hash bcc: '%s'  count: %d", mod_name, string(total), i)
     }
  }
  return string(total), nil
}
