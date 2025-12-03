# Use official lightweight Python image
FROM python:3.12-slim

# Prevent Python from writing .pyc files and buffering stdout
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set working directory inside container
WORKDIR /app

# Copy dependency list
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the app
COPY . .

# Expose Flask/Gunicorn port
EXPOSE 5000

# Run the app with Gunicorn in production
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app"]
