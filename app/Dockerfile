# Use the official Python image as the base image
FROM python:3.12-slim

# Set the working directory in the container
WORKDIR /app

# Copy the application code into the container
COPY server.py /app/

# Install any required Python packages
COPY requirements.txt /app/
RUN pip3 install --no-cache-dir -r requirements.txt

# Expose the port the application runs on
EXPOSE 8080

# Command to run the application
CMD ["python3", "server.py"]