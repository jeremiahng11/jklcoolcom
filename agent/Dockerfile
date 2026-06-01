# Optional: run the metrics agent as a Docker container (e.g. deploy on Coolify).
# For accurate HOST metrics, the container must see the host's /proc and disk:
#
#   docker run -d --name coolify-companion-agent --restart unless-stopped \
#     -p 8088:8088 \
#     -e METRICS_TOKEN=your-secret \
#     -e PROC_PATH=/host/proc -e DISK_PATH=/host/root \
#     -v /proc:/host/proc:ro -v /:/host/root:ro \
#     <image>
#
# (On Coolify: deploy this as a Docker image / compose resource, set the env
#  vars and the two read-only bind mounts above, expose port 8088.)
FROM python:3.12-alpine
WORKDIR /app
COPY agent.py .
ENV METRICS_PORT=8088 PROC_PATH=/host/proc DISK_PATH=/host/root
EXPOSE 8088
CMD ["python3", "agent.py"]
