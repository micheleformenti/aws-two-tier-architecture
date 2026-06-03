# Use official Python runtime as base image
FROM python:3.11-slim

# Set working directory in container
WORKDIR /source

# Copy requirements file
COPY source/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY source .

# Expose port 5000
EXPOSE 5000

# Set environment variables
ENV FLASK_APP=app.py
ENV PYTHONUNBUFFERED=1

# Run the application
CMD ["python", "app.py"]