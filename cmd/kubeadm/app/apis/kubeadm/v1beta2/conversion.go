/*
Copyright 2019 The Kubernetes Authors.

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
	conversion "k8s.io/apimachinery/pkg/conversion"
	kubeadm "k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm"
)

func Convert_kubeadm_InitConfiguration_To_v1beta2_InitConfiguration(in *kubeadm.InitConfiguration, out *InitConfiguration, s conversion.Scope) error {
	if err := autoConvert_kubeadm_InitConfiguration_To_v1beta2_InitConfiguration(in, out, s); err != nil {
		return err
	}

	out.PublicKeyAlgorithm = &PublicKeyAlgorithm{
		PublicKeyAlgorithm: in.PublicKeyAlgorithm,
	}
	return nil
}

func Convert_v1beta2_InitConfiguration_To_kubeadm_InitConfiguration(in *InitConfiguration, out *kubeadm.InitConfiguration, s conversion.Scope) error {
	err := autoConvert_v1beta2_InitConfiguration_To_kubeadm_InitConfiguration(in, out, s)
	if err != nil {
		return err
	}

	// Keep the fuzzer test happy by setting out.ClusterConfiguration to defaults
	clusterCfg := &ClusterConfiguration{}
	SetDefaults_ClusterConfiguration(clusterCfg)
	if in.PublicKeyAlgorithm != nil {
		out.PublicKeyAlgorithm = in.PublicKeyAlgorithm.PublicKeyAlgorithm
	}
	return Convert_v1beta2_ClusterConfiguration_To_kubeadm_ClusterConfiguration(clusterCfg, &out.ClusterConfiguration, s)
}

func Convert_kubeadm_PublicKeyAlgorithm_To_v1beta2_PublicKeyAlgorithm(in *kubeadm.PublicKeyAlgorithm, out *PublicKeyAlgorithm, s conversion.Scope) error {
	out.PublicKeyAlgorithm = *in
	return nil
}

func Convert_v1beta2_PublicKeyAlgorithm_To_kubeadm_PublicKeyAlgorithm(in *PublicKeyAlgorithm, out *kubeadm.PublicKeyAlgorithm, s conversion.Scope) error {
	*out = in.PublicKeyAlgorithm
	return nil
}
