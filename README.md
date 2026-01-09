# LanceDB Viewer

![image](./frontend/static/image.png)

## Fork Information

This project is forked from [mythrantic/lancedb-viewer](https://github.com/mythrantic/lancedb-viewer). The original repository provides a comprehensive LanceDB viewer interface, and this fork includes additional improvements and customizations for enhanced functionality.

---

## About

LanceDB Viewer is a user-friendly tool designed to interact with LanceDB, offering a visual interface for performing Create, Read, Update, and Delete (CRUD) operations. This project aims to simplify database management and enhance productivity.

## Features

- **Visual Interface**: Easily browse and manage LanceDB databases.
- **CRUD Support**: Perform Create, Read, Update, and Delete operations seamlessly.
- **Developer-Friendly**: Designed for both end-users and contributors.

## Tech Stack

- **Backend**: Python (FastAPI)
- **Frontend**: SvelteKit
- **Database**: LanceDB

---

## Getting Started

### Prerequisites

Ensure you have the following installed on your system:

- **Node.js** (v16 or higher)
- **Python** (v3.8 or higher)
- **npm** (comes with Node.js)

---

### Running the Application

#### Easy Way (Recommended)

Use the provided runner script from the root directory:

```bash
cd /Users/puspa.kirana/Documents/GitHub/lancedb_viewer
./runner.sh start
```

Available commands:
- `./runner.sh start` - Start both backend and frontend servers
- `./runner.sh stop` - Stop both servers  
- `./runner.sh restart` - Restart both servers
- `./runner.sh status` - Check running status

#### Manual Setup

To start the application in development mode manually:

1.  Clone the repository:

    ```bash
    git clone https://github.com/valiantlynx/lancedb-viewer.git
    cd lancedb-viewer
    ```

2.  Start the backend server:

    ```bash
    cd backend/src
    python3 -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload
    ```

3.  Start the frontend development server:

    ```bash
    cd frontend
    npm install
    npm run dev
    ```

4.  Open your browser and navigate to [http://localhost:5173](http://localhost:5173).

**Access URLs:**
- Frontend: http://localhost:5173
- Backend API: http://localhost:8001

---

## Contributing

If you'd like to contribute:

1.  Set up a development environment using Docker Compose:

    ```bash
    docker-compose up --build
    ```

    This will set up a complete development environment for testing and contributing.

    or do it however you like

2.  Make your changes and submit a Pull Request.

---

## License

This project is open source. Check the repository for license details.

---

## Contact

For questions or suggestions, please open an issue in the GitHub repository.
