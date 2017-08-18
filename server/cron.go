// Copyright (C) 2015 NTT Innovation Institute, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
// implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package server

import (
	"fmt"
	"strings"

	"github.com/robfig/cron"

	"errors"
	l "github.com/cloudwan/gohan/log"
	"github.com/cloudwan/gohan/util"
	"github.com/twinj/uuid"
)

//CRON Process
func startCRONProcess(server *Server) {
	traceID := uuid.NewV4().String()
	config := util.GetConfig()
	jobList := config.GetParam("cron", nil)
	if jobList == nil {
		return
	}
	if server.sync == nil {
		log.Fatalf(fmt.Sprintf("[%s] Could not start CRON process because of sync backend misconfiguration.", traceID))
		l.FatalPanic(log)
	}
	log.Info("[%s] Started CRON process", traceID)
	c := cron.New()
	var jobLocks = map[string](chan int){}

	for _, rawJob := range jobList.([]interface{}) {
		job := rawJob.(map[string]interface{})
		path := job["path"].(string)
		timing := job["timing"].(string)
		name := strings.TrimPrefix(path, "cron://")
		log.Info("[%s] New job for %s / %s", traceID, path, timing)
		lockKey := lockPath + "/" + name
		jobLocks[lockKey] = make(chan int, 1)
		jobLocks[lockKey] <- 1
		env, err := server.NewEnvironmentForPath(name, path)
		if err != nil {
			log.Fatal(err.Error())
		}

		takeLock := func() error {
			select {
			case <-jobLocks[lockKey]:
				_, err := server.sync.Lock(lockKey, false)
				if err != nil {
					log.Debug("[%s] Failed to take ETCD lock", traceID)
					jobLocks[lockKey] <- 1
				}
				return err
			default:
				log.Debug("Failed to take lock: %s", lockKey)
				return errors.New("Another cron job is running")
			}
		}

		c.AddFunc(timing, func() {
			err := takeLock()
			if err != nil {
				log.Info("[%s] Failed to schedule cron job, err: %s", traceID, err.Error())
				return
			}
			defer func() {
				if r := recover(); r != nil {
					log.Error("[%s] Cron job '%s' panicked: %s", traceID, path, r)
				}
				log.Debug("[%s] Unlocking %s", traceID, lockKey)
				jobLocks[lockKey] <- 1
				server.sync.Unlock(lockKey)
			}()

			context := map[string]interface{}{
				"path": path,
			}
			if err != nil {
				log.Warning(fmt.Sprintf("[%s] extension error: %s", traceID, err))
				return
			}
			clone := env.Clone()
			if err := clone.HandleEvent("notification", context, traceID); err != nil {
				log.Warning(fmt.Sprintf("extension error: %s", err))
				return
			}
			return
		})
	}
	c.Start()
}

func stopCRONProcess(server *Server) {

}
