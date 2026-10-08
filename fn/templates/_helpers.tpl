{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified postgresql name.
*/}}
{{- define "postgresql.fullname" -}}
{{- printf "%s-%s" .Release.Name "postgresql" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified redis name.
*/}}
{{- define "redis.fullname" -}}
{{- printf "%s-%s" .Release.Name "redis" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Assemble the public load balancer URL.
*/}}
{{- define "fn.public_lb_url" -}}
{{- printf "%s.%s:%.0f" .Release.Name .Values.fn_lb_runner.service.ingress_hostname .Values.fn_lb_runner.service.port }}
{{- end }}

{{/*
Name of the TLS secret used by the Ingress / ACME issuer.
Defaults to <release>-fn-tls unless tls.secret_reference is set.
*/}}
{{- define "fn.tls_secret_name" -}}
{{- default (printf "%s-fn-tls" .Release.Name) .Values.tls.secret_reference -}}
{{- end -}}