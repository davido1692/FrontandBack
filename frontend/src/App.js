import React, { useEffect, useState } from 'react'
import './App.css';
import config from './config'

function App() {
  const [successMessage, setSuccessMessage] = useState() 
  const [failureMessage, setFailureMessage] = useState() 

  useEffect(() => {
    const getId = async () => {
      try {
        const resp = await fetch(config.backendUrl)
        setSuccessMessage((await resp.json()).id)
      }
      catch(e) {
        setFailureMessage(e.message)
      }
    }
    getId()
  }, [])

  return (
    <div className="App">
      {!failureMessage && !successMessage ? 'Fetching...' : null}
      {failureMessage ? failureMessage : null}
      {successMessage ? successMessage : null}
    </div>
  );
}

export default App;