/*

   протокол:
   информация: файл WE2110_P54.pdf
   контроллер: we2110

*/

package scales

import (
	"fmt"
	"math"
	db "reading_from_scales/src/database"
	"regexp"
	"strconv"
	"strings"
)

func (c *Config) Processing_autobelazes(message string) error {
	kaw := db.Kep_analytics_weight{}
	msg := regexp.MustCompile("(?m).*"+c.Command+"(.*)"+"#.*$").ReplaceAllString(message, "$1")
	msg = regexp.MustCompile("(?m)[\\s"+string(STX)+string(ETX)+"]+").ReplaceAllString(msg, "$1")

	if c.Coefficient == 0 {
		c.Coefficient = 1
	}

	weightStr := strings.TrimSpace(message)
	if weightStr == "" {
		return fmt.Errorf("no data for weight")
	}

	weightFloat, err := strconv.ParseFloat(weightStr, 64)
	if err != nil {
		return fmt.Errorf("не удалось преобразовать вес: %v", err)
	}

	weight := int(math.Round(weightFloat * c.Coefficient))

	if c.Type == "marten" {
		c.ch_message <- fmt.Sprintf("d|:|%s: vvvvvvv'", mod_name)
		if len(weightStr) > 0 && weightStr[len(weightStr)-1] == 'G' {
			kaw.Weight_stabilized_1 = "1"
			weightStr = strings.TrimSuffix(weightStr, "G")
			c.ch_message <- fmt.Sprintf("d|:|%s: is stabilazed", mod_name)
		} else {
			kaw.Weight_stabilized_1 = "0"
			c.ch_message <- fmt.Sprintf("d|:|%s: is  not stabilazed", mod_name)
		}
	}

	if _, err := strconv.Atoi(c.get_value(weightStr)); err == nil {
		kaw.Weight_platform_1 = c.get_value(weightStr)
		kaw.Weight = kaw.Weight_platform_1
	}

	kaw.Id_scales = fmt.Sprintf("%d", c.Id_scale)
	kaw.Timestamp = c.get_datetime("")
	kaw.Weight = fmt.Sprintf("%d", weight)
	kaw.Weight_platform_1 = kaw.Weight

	if c.Type == "autobelazes" {
		kaw.Weight_stabilized_1 = "1"
	}

	if DEBUG.enable {
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing %s  message: %v", mod_name, c.Type, msg)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing %s  id_scale: %s  timestamp: %s", mod_name, c.Type, kaw.Id_scales, kaw.Timestamp)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing %s  id_scale: %s  weight: %s", mod_name, c.Type, kaw.Id_scales, kaw.Weight)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing %s  id_scale: %s  weight_platform_1: %s", mod_name, c.Type, kaw.Id_scales, kaw.Weight_platform_1)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing %s  id_scale: %s  weight_stabilized_1: %s", mod_name, c.Type, kaw.Id_scales, kaw.Weight_stabilized_1)
	}

	select {
	case c.ch_db_message <- kaw:
	default:
	}
	return nil
}
