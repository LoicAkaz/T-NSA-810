# -*- coding: utf-8 -*-
# =============================================================================
# Callback Ansible — node_exporter_textfile
# Écrit l'état du dernier run (ansible-pull) dans un fichier .prom lu par le
# textfile collector de node_exporter, pour supervision via Prometheus.
#
# Activation (ansible.cfg) :
#   callback_plugins  = callback_plugins
#   callbacks_enabled = node_exporter_textfile
#
# Fichier produit : /var/lib/node_exporter/textfile_collector/ansible_pull.prom
# (override possible via la variable d'env ANSIBLE_PULL_TEXTFILE)
# =============================================================================

from __future__ import absolute_import, division, print_function

__metaclass__ = type

import os
import tempfile
import time

from ansible.plugins.callback import CallbackBase


DEFAULT_TEXTFILE = "/var/lib/node_exporter/textfile_collector/ansible_pull.prom"


class CallbackModule(CallbackBase):
    """Expose les stats du run comme métriques node_exporter (textfile)."""

    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "notification"
    CALLBACK_NAME = "node_exporter_textfile"
    CALLBACK_NEEDS_ENABLED = True

    def __init__(self, *args, **kwargs):
        super(CallbackModule, self).__init__(*args, **kwargs)
        self.textfile_path = os.environ.get("ANSIBLE_PULL_TEXTFILE", DEFAULT_TEXTFILE)

    def v2_playbook_on_stats(self, stats):
        ok = changed = failures = unreachable = skipped = 0
        for host in stats.processed.keys():
            summary = stats.summarize(host)
            ok += summary.get("ok", 0)
            changed += summary.get("changed", 0)
            failures += summary.get("failures", 0)
            unreachable += summary.get("unreachable", 0)
            skipped += summary.get("skipped", 0)

        # failed_tasks = échecs de tâches + hosts injoignables (dark)
        failed_tasks = failures + unreachable

        lines = [
            "# HELP ansible_pull_last_run_timestamp_seconds Unix time du dernier run ansible-pull terminé.",
            "# TYPE ansible_pull_last_run_timestamp_seconds gauge",
            "ansible_pull_last_run_timestamp_seconds {0}".format(int(time.time())),
            "# HELP ansible_pull_failed_tasks Nombre de tâches en échec (failures + unreachable) au dernier run.",
            "# TYPE ansible_pull_failed_tasks gauge",
            "ansible_pull_failed_tasks {0}".format(failed_tasks),
            "# HELP ansible_pull_changed_tasks Nombre de tâches changed au dernier run.",
            "# TYPE ansible_pull_changed_tasks gauge",
            "ansible_pull_changed_tasks {0}".format(changed),
            "# HELP ansible_pull_ok_tasks Nombre de tâches ok au dernier run.",
            "# TYPE ansible_pull_ok_tasks gauge",
            "ansible_pull_ok_tasks {0}".format(ok),
            "# HELP ansible_pull_skipped_tasks Nombre de tâches skipped au dernier run.",
            "# TYPE ansible_pull_skipped_tasks gauge",
            "ansible_pull_skipped_tasks {0}".format(skipped),
        ]
        content = "\n".join(lines) + "\n"

        self._write_atomic(content)

    def _write_atomic(self, content):
        """Écriture atomique : tmp dans le même dir + rename, pour que
        node_exporter ne lise jamais un fichier à moitié écrit."""
        target_dir = os.path.dirname(self.textfile_path)
        try:
            if target_dir and not os.path.isdir(target_dir):
                os.makedirs(target_dir)

            fd, tmp_path = tempfile.mkstemp(dir=target_dir, prefix=".ansible_pull-")
            try:
                with os.fdopen(fd, "w") as fh:
                    fh.write(content)
                os.chmod(tmp_path, 0o644)
                os.rename(tmp_path, self.textfile_path)
            except Exception:
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)
                raise
        except Exception as exc:
            # Ne jamais faire échouer le run pour un problème de métrique.
            self._display.warning(
                "node_exporter_textfile: impossible d'écrire %s (%s)"
                % (self.textfile_path, exc)
            )
