from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List
from fastapi import APIRouter
import os

from database import engine, get_db, Base
from models import Todo
from schemas import TodoCreate, TodoUpdate, TodoResponse

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Todo API", version="1.0.0")


@app.on_event("startup")
async def startup_event():
    import logging

    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger("uvicorn")
    logger.info(f"Connecting to DB at host: {os.getenv('DB_HOST')}")
    try:
        # Try to create a connection to verify it works
        with engine.connect() as _:
            logger.info("Successfully connected to the database!")
    except Exception as e:
        logger.error(f"Failed to connect to database: {str(e)}")


# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins since nginx will be the entry point
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Create API Router with prefix
api_router = APIRouter(prefix="/api")


@app.get("/")
def read_root():
    return {"message": "Todo API is running"}


@api_router.get("/todos", response_model=List[TodoResponse])
def get_todos(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """Get all todos"""
    todos = db.query(Todo).offset(skip).limit(limit).all()
    return todos


@api_router.get("/todos/{todo_id}", response_model=TodoResponse)
def get_todo(todo_id: int, db: Session = Depends(get_db)):
    """Get a specific todo by ID"""
    todo = db.query(Todo).filter(Todo.id == todo_id).first()
    if todo is None:
        raise HTTPException(status_code=404, detail="Todo not found")
    return todo


@api_router.post("/todos", response_model=TodoResponse, status_code=201)
def create_todo(todo: TodoCreate, db: Session = Depends(get_db)):
    """Create a new todo"""
    db_todo = Todo(**todo.model_dump())
    db.add(db_todo)
    db.commit()
    db.refresh(db_todo)
    return db_todo


@api_router.put("/todos/{todo_id}", response_model=TodoResponse)
def update_todo(todo_id: int, todo: TodoUpdate, db: Session = Depends(get_db)):
    """Update an existing todo"""
    db_todo = db.query(Todo).filter(Todo.id == todo_id).first()
    if db_todo is None:
        raise HTTPException(status_code=404, detail="Todo not found")

    # Update only provided fields
    update_data = todo.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_todo, key, value)

    db.commit()
    db.refresh(db_todo)
    return db_todo


@api_router.delete("/todos/{todo_id}", status_code=204)
def delete_todo(todo_id: int, db: Session = Depends(get_db)):
    """Delete a todo"""
    db_todo = db.query(Todo).filter(Todo.id == todo_id).first()
    if db_todo is None:
        raise HTTPException(status_code=404, detail="Todo not found")

    db.delete(db_todo)
    db.commit()
    return None


app.include_router(api_router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
