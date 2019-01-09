/*
Copyright 2016 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package util

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/pkg/errors"

	netutil "k8s.io/apimachinery/pkg/util/net"
	"k8s.io/klog"
)

const (
	getReleaseVersionTimeout = time.Duration(10 * time.Second)
)

var (
	kubeReleaseBucketURL  = "https://dl.k8s.io"
	kubeReleaseLabelRegex = regexp.MustCompile(`^[[:lower:]]+(-[-\w_\.]+)?$`)
)

// IsVersionLabel checks if the input string is version label
func IsVersionLabel(label string) bool {
	return kubeReleaseLabelRegex.MatchString(label)
}

// KubernetesVersionToImageTag is helper function that replaces all
// non-allowed symbols in tag strings with underscores.
// Image tag can only contain lowercase and uppercase letters, digits,
// underscores, periods and dashes.
// Current usage is for CI images where all of symbols except '+' are valid,
// but function is for generic usage where input can't be always pre-validated.
func KubernetesVersionToImageTag(version string) string {
	allowed := regexp.MustCompile(`[^-a-zA-Z0-9_\.]`)
	return allowed.ReplaceAllString(version, "_")
}

// ResolveVersionLabel fetches version for given label from remote server's bucket and tries to parse it.
//
// Available names on release servers:
//  stable      (latest stable release)
//  stable-1    (latest stable release in 1.x)
//  stable-1.0  (and similarly 1.1, 1.2, 1.3, ...)
//  latest      (latest release, including alpha/beta)
//  latest-1    (latest release in 1.x, including alpha/beta)
//  latest-1.0  (and similarly 1.1, 1.2, 1.3, ...)
func ResolveVersionLabel(bucket, label string) (string, error) {
	if !IsVersionLabel(label) {
		return "", errors.Errorf("Invalid version label: %s", label)
	}

	client := &http.Client{Timeout: getReleaseVersionTimeout, Transport: netutil.SetOldTransportDefaults(&http.Transport{})}
	ver := label
	// try to resolve recursive labels like "stable" -> "stable-1" -> parsable version
	for attempts := 0; attempts < 4; attempts++ {
		url := fmt.Sprintf("%s/%s/%s.txt", kubeReleaseBucketURL, bucket, ver)
		klog.V(2).Infof("fetching Kubernetes version from URL: %s", url)
		resp, err := client.Get(url)
		if err != nil {
			return "", errors.Wrapf(err, "unable to get URL %q", url)
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			return "", errors.Errorf("unable to fetch file. URL: %q, status: %v", url, resp.Status)
		}
		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return "", errors.Wrapf(err, "unable to read content of URL %q", url)
		}
		ver = strings.TrimSpace(string(body))

		if !IsVersionLabel(ver) {
			return ver, nil
		}
	}

	return "", errors.New("exhausted all attempts to resolve recursive remote version")
}
