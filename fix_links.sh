#!/usr/bin/env bash

prefix=/local/mnt/workspace/amakarov

for link in *; do
    if [ -L "$link" ]; then
        target=$(readlink "$link")
        if [[ "$target" =~ ^/nix/store/([a-z0-9]{32}-.+)$ ]]; then
            new_target="${prefix}/nix/store/${BASH_REMATCH[1]}"
            echo "$link -> $new_target"
            ln -sf "$new_target" "$link"
        fi
    fi
done
