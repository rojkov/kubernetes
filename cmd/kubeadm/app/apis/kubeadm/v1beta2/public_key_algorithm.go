/*
Copyright 2020 The Kubernetes Authors.

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

package v1beta2

import (
	"encoding/json"
	"strings"

	"github.com/pkg/errors"
	kubeadm "k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm"
)

// PublicKeyAlgorithm is a wrapper around kubeadm.PublicKeyAlgorithm which supports
// correct marshaling to YAML and JSON. In particular, it marshals into strings.
type PublicKeyAlgorithm struct {
	kubeadm.PublicKeyAlgorithm `protobuf:"varint,1,opt,name=publicKeyAlgorithm,casttype=kubeadm.PublicKeyAlgorithm"`
}

// UnmarshalJSON implements the json.Unmarshaller interface.
func (a *PublicKeyAlgorithm) UnmarshalJSON(b []byte) error {
	var str string
	err := json.Unmarshal(b, &str)
	if err != nil {
		return err
	}

	switch strings.ToUpper(strings.TrimSpace(str)) {
	case "RSA":
		a.PublicKeyAlgorithm = kubeadm.RSA
	case "ECDSA":
		a.PublicKeyAlgorithm = kubeadm.ECDSA
	default:
		return errors.Errorf("unsupported public key algorithm name: %q", str)
	}

	return nil
}

// MarshalJSON implements the json.Marshaler interface.
func (a PublicKeyAlgorithm) MarshalJSON() ([]byte, error) {
	return json.Marshal(a.PublicKeyAlgorithm.String())
}
